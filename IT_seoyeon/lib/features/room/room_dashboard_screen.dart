import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'tabs/course_tab_view.dart';
import 'tabs/member_tab_view.dart';
import 'tabs/place_tab_view.dart';
import 'tabs/schedule_tab_view.dart';

class RoomDashboardScreen extends StatefulWidget{final TravelRoom room;final int initialTab;const RoomDashboardScreen({super.key,required this.room,this.initialTab=0});@override State<RoomDashboardScreen> createState()=>_RoomDashboardScreenState();}
class _RoomDashboardScreenState extends State<RoomDashboardScreen> with SingleTickerProviderStateMixin{
 late TravelRoom _room;late TabController _tabs;final _repo=SupabaseRepository();
 @override void initState(){super.initState();_room=widget.room;_tabs=TabController(length:4,vsync:this,initialIndex:widget.initialTab);}
 Future<void> _settings()async{final members=await _repo.getMembers(_room.id);RoomMember? me;for(final m in members){if(m.userId==_repo.currentUserId)me=m;}final owner=me?.role==MemberRole.owner;if(!mounted)return;showModalBottomSheet(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.copy),title:const Text('초대 코드 복사'),subtitle:Text(_room.inviteCode??'-'),onTap:(){Clipboard.setData(ClipboardData(text:_room.inviteCode??''));Navigator.pop(ctx);}),if(owner)ListTile(leading:const Icon(Icons.swap_horiz),title:const Text('방장 위임'),onTap:(){Navigator.pop(ctx);_transfer(members);}),ListTile(leading:const Icon(Icons.exit_to_app,color:Colors.red),title:Text(owner?'방 삭제 후 나가기':'방 나가기',style:const TextStyle(color:Colors.red)),onTap:(){Navigator.pop(ctx);_leave(owner);})])));}
 Future<void> _transfer(List<RoomMember> members)async{final others=members.where((m)=>m.userId!=_repo.currentUserId).toList();if(others.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('위임할 멤버가 없습니다.')));return;}final id=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:const Text('새 방장 선택'),children:others.map((m)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,m.userId),child:Text(m.nickname))).toList()));if(id!=null){await _repo.transferOwnership(_room.id,id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('방장을 위임했습니다.')));}}
 Future<void> _leave(bool owner)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(owner?'방을 삭제할까요?':'방에서 나갈까요?'),content:Text(owner?'위임하지 않고 나가면 방의 일정·장소·기록 데이터가 모두 삭제되며 복구할 수 없습니다.':'내 참여 정보가 삭제됩니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(owner?'삭제':'나가기'))]));if(ok==true){await _repo.leaveRoom(_room.id);if(mounted)Navigator.of(context).popUntil((r)=>r.isFirst);}}
 @override void dispose(){_tabs.dispose();super.dispose();}
 Widget _locked(String name)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_clock,size:54,color:AppColors.textSecondary),const SizedBox(height:12),Text('여행 날짜를 확정한 뒤 $name 정보를 입력할 수 있습니다.',textAlign:TextAlign.center)])));
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_room.name),Text('${_room.tripDurationLabel} · ${_room.isScheduleFinalized?'일정 확정':'일정 조율 중'}',style:const TextStyle(fontSize:12,color:AppColors.textSecondary))]),actions:[IconButton(onPressed:_settings,icon:const Icon(Icons.settings))],bottom:TabBar(controller:_tabs,tabs:const [Tab(text:'일정'),Tab(text:'장소'),Tab(text:'코스'),Tab(text:'멤버')])),body:TabBarView(controller:_tabs,children:[ScheduleTabView(roomId:_room.id),_room.isScheduleFinalized?PlaceTabView(roomId:_room.id):_locked('장소'),_room.isScheduleFinalized?CourseTabView(roomId:_room.id):_locked('코스'),MemberTabView(room:_room)]));
}
