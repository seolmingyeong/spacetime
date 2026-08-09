import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import 'room_dashboard_screen.dart';

class RoomCreateScreen extends StatefulWidget {
  const RoomCreateScreen({super.key});
  @override State<RoomCreateScreen> createState()=>_RoomCreateScreenState();
}
class _RoomCreateScreenState extends State<RoomCreateScreen>{
  final _name=TextEditingController(); int _days=1; bool _recommend=true,_loading=false;
  String _code(){const c='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';final r=Random.secure();return List.generate(6,(_)=>c[r.nextInt(c.length)]).join();}
  String _label(int d)=>d==1?'당일치기':'${d-1}박 $d일';
  Future<void> _save()async{
    if(_name.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('방 이름을 입력해 주세요.')));return;}
    setState(()=>_loading=true);
    try{final room=await SupabaseRepository().createRoom(name:_name.text,inviteCode:_code(),tripDays:_days,placeRecommendationEnabled:_recommend);
      if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>RoomDashboardScreen(room:room)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('방 생성 실패: $e')));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  @override void dispose(){_name.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('새 방 만들기')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('여행 기본 정보',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),const Text('실제 날짜는 모든 멤버의 가능한 날을 모아 결정합니다.',style:TextStyle(color:AppColors.textSecondary)),
      const SizedBox(height:24),TextField(controller:_name,maxLength:30,decoration:const InputDecoration(labelText:'방 이름',hintText:'예: 제주도 여름 여행',border:OutlineInputBorder(),prefixIcon:Icon(Icons.groups))),
      const SizedBox(height:16),const Text('여행 기간',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:List.generate(7,(i){final d=i+1;return ChoiceChip(label:Text(_label(d)),selected:_days==d,onSelected:(_)=>setState(()=>_days=d));})),
      const SizedBox(height:24),Card(child:SwitchListTile(value:_recommend,onChanged:(v)=>setState(()=>_recommend=v),secondary:const Icon(Icons.auto_awesome,color:AppColors.room),title:const Text('AI 장소 추천'),subtitle:Text(_recommend?'취향과 이동을 고려한 장소 추천을 사용합니다.':'장소를 직접 검색하고 추가합니다.'))),
      const SizedBox(height:28),FilledButton(onPressed:_loading?null:_save,style:FilledButton.styleFrom(backgroundColor:AppColors.room,padding:const EdgeInsets.all(16)),child:_loading?const CircularProgressIndicator():const Text('방 만들기')),
    ]));
}
