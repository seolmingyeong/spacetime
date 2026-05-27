from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, join_room, emit
import json, random, string, math, os
from datetime import datetime
from collections import defaultdict

app = Flask(__name__)
app.secret_key = 'spacetime-secret-2024'
socketio = SocketIO(app, cors_allowed_origins="*")

DB_FILE = 'rooms_db.json'

def load_rooms():
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_rooms():
    with open(DB_FILE, 'w', encoding='utf-8') as f:
        json.dump(rooms, f, ensure_ascii=False, indent=2)

rooms = load_rooms()

def generate_room_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

# ─── ROUTES ───────────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/room/<code>')
def room_page(code):
    return render_template('room.html', room_code=code)

@app.route('/api/create-room', methods=['POST'])
def create_room():
    data = request.json
    room_name = data.get('room_name', '').strip()
    host_name = data.get('host_name', '').strip()
    if not room_name or not host_name:
        return jsonify({'error': '방 이름과 호스트 이름을 입력해주세요'}), 400
    code = generate_room_code()
    while code in rooms:
        code = generate_room_code()
    rooms[code] = {
        'code': code, 'name': room_name,
        'created_at': datetime.now().isoformat(),
        'phase': 'collect',
        'participants': {},
        'schedule_result': None,
        'place_result': None,
    }
    save_rooms()
    return jsonify({'code': code, 'room_name': room_name})

@app.route('/api/room/<code>', methods=['GET'])
def get_room(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    return jsonify(sanitize_room(room))

@app.route('/api/room/<code>/join', methods=['POST'])
def join_room_api(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    data = request.json
    name = data.get('name', '').strip()
    if not name:
        return jsonify({'error': '이름을 입력해주세요'}), 400
    if name not in room['participants']:
        room['participants'][name] = {
            'name': name, 'timezone': 'Asia/Seoul',
            'available_dates': [], 'available_times': {},
            'availability_submitted': False,
            'departure': None, 'transport': None,
            'categories': [], 'transport_submitted': False,
        }
        save_rooms()
        socketio.emit('room_update', sanitize_room(room), room=code)
    return jsonify({'ok': True, 'name': name})

@app.route('/api/room/<code>/submit-availability', methods=['POST'])
def submit_availability(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    data = request.json
    name = data.get('name')
    if name not in room['participants']:
        return jsonify({'error': '참여자를 찾을 수 없습니다'}), 404
    room['participants'][name]['available_dates'] = data.get('dates', [])
    room['participants'][name]['available_times'] = data.get('times', {})
    room['participants'][name]['timezone'] = data.get('timezone', 'Asia/Seoul')
    room['participants'][name]['availability_submitted'] = True
    all_submitted = all(p['availability_submitted'] for p in room['participants'].values())
    if all_submitted:
        room['schedule_result'] = compute_schedule(room)
    save_rooms()
    socketio.emit('room_update', sanitize_room(room), room=code)
    return jsonify({'ok': True})

@app.route('/api/room/<code>/reset-availability', methods=['POST'])
def reset_availability(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    name = request.json.get('name')
    if name not in room['participants']:
        return jsonify({'error': '참여자를 찾을 수 없습니다'}), 404
    room['participants'][name]['availability_submitted'] = False
    room['schedule_result'] = None
    save_rooms()
    socketio.emit('room_update', sanitize_room(room), room=code)
    return jsonify({'ok': True})

@app.route('/api/room/<code>/reset-transport', methods=['POST'])
def reset_transport(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    name = request.json.get('name')
    if name not in room['participants']:
        return jsonify({'error': '참여자를 찾을 수 없습니다'}), 404
    room['participants'][name]['transport_submitted'] = False
    room['place_result'] = None
    save_rooms()
    socketio.emit('room_update', sanitize_room(room), room=code)
    return jsonify({'ok': True})

@app.route('/api/room/<code>/advance-phase', methods=['POST'])
def advance_phase(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    phase = request.json.get('phase')
    if phase:
        room['phase'] = phase
        if phase == 'collect':
            for p in room['participants'].values():
                p['availability_submitted'] = False
            room['schedule_result'] = None
            room['place_result'] = None
        elif phase == 'schedule':
            room['place_result'] = None
        elif phase == 'place':
            for p in room['participants'].values():
                p['transport_submitted'] = False
            room['place_result'] = None
    save_rooms()
    socketio.emit('room_update', sanitize_room(room), room=code)
    return jsonify({'ok': True})

@app.route('/api/room/<code>/submit-transport', methods=['POST'])
def submit_transport(code):
    room = rooms.get(code)
    if not room:
        return jsonify({'error': '방을 찾을 수 없습니다'}), 404
    data = request.json
    name = data.get('name')
    if name not in room['participants']:
        return jsonify({'error': '참여자를 찾을 수 없습니다'}), 404
    room['participants'][name]['departure'] = data.get('departure', '')
    room['participants'][name]['transport'] = data.get('transport', '')
    room['participants'][name]['categories'] = data.get('categories', [])
    room['participants'][name]['transport_submitted'] = True
    all_submitted = all(p['transport_submitted'] for p in room['participants'].values())
    if all_submitted:
        room['place_result'] = compute_places(room)
        room['phase'] = 'result'
    save_rooms()
    socketio.emit('room_update', sanitize_room(room), room=code)
    return jsonify({'ok': True})

# ─── COMPUTATION ──────────────────────────────────────────────────────────────
def compute_schedule(room):
    participants = room['participants']
    if not participants:
        return None
    date_counts = defaultdict(list)
    for name, p in participants.items():
        for d in p.get('available_dates', []):
            date_counts[d].append(name)
    total = len(participants)
    common_dates_times = {}
    for date, names in date_counts.items():
        if len(names) == total:
            hour_sets = [set(participants[n].get('available_times', {}).get(date, [])) for n in names]
            common_hours = sorted(hour_sets[0].intersection(*hour_sets[1:])) if hour_sets else []
            common_dates_times[date] = common_hours
    common_dates = sorted(common_dates_times.keys())
    best_dates = sorted(date_counts.items(), key=lambda x: -len(x[1]))[:7]
    return {
        'common_dates': common_dates,
        'common_dates_times': common_dates_times,
        'best_dates': [{'date': d, 'participants': names, 'count': len(names)} for d, names in best_dates],
        'total_participants': total,
    }

TRANSPORT_SPEEDS = {'도보': 5, '자전거': 15, '대중교통': 40, '자동차': 60, '택시': 55}
TAXI_BASE = 4800
TAXI_PER_KM = 900

CATEGORY_PLACES = {
    '맛집': ['강남 맛집 골목', '홍대 푸드스트리트', '이태원 레스토랑', '명동 먹자골목'],
    '카페': ['성수 카페거리', '연남동 카페', '익선동 한옥카페', '압구정 디저트카페'],
    '관광': ['경복궁', '남산타워', '북촌한옥마을', '인사동'],
    '쇼핑': ['명동 쇼핑', '강남 코엑스몰', '홍대 쇼핑거리', '동대문 쇼핑'],
    '자연': ['한강공원', '북한산', '서울숲', '올림픽공원'],
    '문화': ['국립중앙박물관', '예술의전당', 'DDP 동대문디자인플라자', '광화문광장'],
    '액티비티': ['롯데월드', '에버랜드', '클라이밍짐', '볼링장'],
    '술집': ['이태원 바거리', '홍대 클럽거리', '강남 가로수길', '신촌 술집거리'],
}

PLACE_COORDS = {
    '강남 맛집 골목':(37.4979,127.0276),'홍대 푸드스트리트':(37.5563,126.9236),
    '이태원 레스토랑':(37.5340,126.9941),'명동 먹자골목':(37.5636,126.9869),
    '성수 카페거리':(37.5447,127.0557),'연남동 카페':(37.5617,126.9249),
    '익선동 한옥카페':(37.5740,126.9994),'압구정 디저트카페':(37.5272,127.0286),
    '경복궁':(37.5796,126.9770),'남산타워':(37.5512,126.9882),
    '북촌한옥마을':(37.5826,126.9830),'인사동':(37.5742,126.9857),
    '명동 쇼핑':(37.5636,126.9869),'강남 코엑스몰':(37.5115,127.0595),
    '홍대 쇼핑거리':(37.5563,126.9236),'동대문 쇼핑':(37.5665,127.0094),
    '한강공원':(37.5283,126.9340),'북한산':(37.6600,126.9770),
    '서울숲':(37.5445,127.0374),'올림픽공원':(37.5200,127.1200),
    '국립중앙박물관':(37.5240,126.9800),'예술의전당':(37.4784,127.0157),
    'DDP 동대문디자인플라자':(37.5669,127.0092),'광화문광장':(37.5759,126.9769),
    '롯데월드':(37.5110,127.0985),'에버랜드':(37.2930,127.2020),
    '클라이밍짐':(37.5400,127.0100),'볼링장':(37.5550,126.9300),
    '이태원 바거리':(37.5340,126.9941),'홍대 클럽거리':(37.5563,126.9236),
    '강남 가로수길':(37.5209,127.0228),'신촌 술집거리':(37.5553,126.9368),
}

DEPARTURE_COORDS = {
    '강남':(37.4979,127.0276),'홍대':(37.5563,126.9236),'강북':(37.6400,127.0100),
    '신촌':(37.5553,126.9368),'종로':(37.5730,126.9794),'이태원':(37.5340,126.9941),
    '잠실':(37.5133,127.1028),'수원':(37.2636,127.0286),'인천':(37.4563,126.7052),
    '분당':(37.3595,127.1052),'일산':(37.6596,126.7717),'기타':(37.5665,126.9780),
}

def haversine(lat1,lon1,lat2,lon2):
    R=6371; dlat=math.radians(lat2-lat1); dlon=math.radians(lon2-lon1)
    a=math.sin(dlat/2)**2+math.cos(math.radians(lat1))*math.cos(math.radians(lat2))*math.sin(dlon/2)**2
    return R*2*math.asin(math.sqrt(a))

def compute_places(room):
    participants = room['participants']
    category_votes = defaultdict(int)
    for p in participants.values():
        for c in p['categories']:
            category_votes[c] += 1
    top_categories = sorted(category_votes, key=lambda x:-category_votes[x]) if category_votes else list(CATEGORY_PLACES.keys())[:3]
    candidates = []
    for cat in top_categories[:3]:
        for place in CATEGORY_PLACES.get(cat, []):
            if place not in candidates:
                candidates.append(place)
    scored = []
    for place in candidates:
        if place not in PLACE_COORDS: continue
        plat,plon = PLACE_COORDS[place]
        total_time=0; per_person={}
        for name,p in participants.items():
            dep=p.get('departure','기타') or '기타'
            transport=p.get('transport','대중교통') or '대중교통'
            dlat2,dlon2=DEPARTURE_COORDS.get(dep,DEPARTURE_COORDS['기타'])
            dist=haversine(dlat2,dlon2,plat,plon)
            speed=TRANSPORT_SPEEDS.get(transport,40)
            time_min=(dist/speed)*60
            taxi_fare=None
            if transport=='택시':
                fare=TAXI_BASE+max(0,dist-1.6)*TAXI_PER_KM
                taxi_fare=round(fare/100)*100
            per_person[name]={'time':round(time_min),'dist':round(dist,1),'taxi_fare':taxi_fare}
            total_time+=time_min
        scored.append({
            'place':place,
            'categories':[cat for cat in top_categories if place in CATEGORY_PLACES.get(cat,[])],
            'total_time':total_time,
            'avg_time':round(total_time/len(participants)) if participants else 0,
            'per_person':per_person,
            'coords':{'lat':plat,'lng':plon},
        })
    scored.sort(key=lambda x:x['total_time'])
    return {'top_categories':top_categories,'recommendations':scored[:5],'category_votes':dict(category_votes)}

def sanitize_room(room):
    return {
        'code':room['code'],'name':room['name'],'phase':room['phase'],
        'participants':room['participants'],
        'schedule_result':room['schedule_result'],
        'place_result':room['place_result'],
        'participant_count':len(room['participants']),
        'created_at':room.get('created_at',''),
    }

@socketio.on('join')
def on_join(data):
    code=data.get('code')
    join_room(code)
    room=rooms.get(code)
    if room: emit('room_update',sanitize_room(room))

if __name__=='__main__':
    import socket as _socket
    try:
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        local_ip = '127.0.0.1'
    print(f"\n{'='*55}")
    print(f"  🚀 SPACETIME 서버 시작!")
    print(f"  로컬:     http://localhost:5000")
    print(f"  같은 와이파이: http://{local_ip}:5000")
    print(f"  (위 주소를 다른 기기에서 접속하세요)")
    print(f"{'='*55}\n")
    socketio.run(app, debug=False, port=5000, host='0.0.0.0')