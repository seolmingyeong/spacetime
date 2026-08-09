import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../auth/login_screen.dart';

class PrivacyAccountScreen extends StatefulWidget{const PrivacyAccountScreen({super.key});@override State<PrivacyAccountScreen> createState()=>_PrivacyAccountScreenState();}
class _PrivacyAccountScreenState extends State<PrivacyAccountScreen>{
 Map<String,dynamic> _p={};bool _loading=true;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final uid=supabase.auth.currentUser!.id;var row=await supabase.from('privacy_preferences').select().eq('user_id',uid).maybeSingle();if(row==null){row=await supabase.from('privacy_preferences').insert({'user_id':uid}).select().single();}if(mounted)setState((){_p=row!;_loading=false;});}
 Future<void> _set(String k,dynamic v)async{setState(()=>_p[k]=v);await supabase.from('privacy_preferences').upsert({'user_id':supabase.auth.currentUser!.id,k:v});}
 Future<void> _logout({bool all=false})async{await supabase.auth.signOut(scope:all?SignOutScope.global:SignOutScope.local);if(mounted)Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const LoginScreen()),(_)=>false);}
 Future<void> _export()async{final data=await supabase.rpc('export_my_data');await Clipboard.setData(ClipboardData(text:const JsonEncoder.withIndent('  ').convert(data)));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('내 데이터 JSON을 클립보드에 복사했습니다.')));}
 Future<void> _withdraw()async{final text=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('회원 탈퇴'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('프로필, 개인 일정, 친구 관계, 기록과 사진이 삭제됩니다. 방장인 방은 위임하거나 삭제한 후 탈퇴할 수 있습니다.'),TextField(controller:text,decoration:const InputDecoration(labelText:'‘회원 탈퇴’ 입력'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,text.text=='회원 탈퇴'),child:const Text('탈퇴'))]));if(ok==true){try{await supabase.rpc('delete_my_account');await _logout(all:true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('개인정보 및 계정')),body:_loading?const Center(child:CircularProgressIndicator()):ListView(children:[
  const ListTile(title:Text('친구 및 공개 범위',style:TextStyle(fontWeight:FontWeight.bold))),
  SwitchListTile(title:const Text('이메일로 나를 찾도록 허용'),value:_p['email_discoverable']??true,onChanged:(v)=>_set('email_discoverable',v)),
  ListTile(title:const Text('친구 요청 허용'),trailing:DropdownButton<String>(value:_p['friend_request_scope']??'everyone',items:const [DropdownMenuItem(value:'everyone',child:Text('모든 사용자')),DropdownMenuItem(value:'friends_of_friends',child:Text('친구의 친구')),DropdownMenuItem(value:'nobody',child:Text('받지 않음'))],onChanged:(v)=>_set('friend_request_scope',v))),
  ListTile(title:const Text('기록 기본 공개 범위'),trailing:DropdownButton<String>(value:_p['default_record_visibility']??'private',items:const [DropdownMenuItem(value:'private',child:Text('비공개')),DropdownMenuItem(value:'friends',child:Text('친구 공개')),DropdownMenuItem(value:'public',child:Text('전체 공개'))],onChanged:(v)=>_set('default_record_visibility',v))),
  const Divider(),const ListTile(title:Text('위치 및 사진',style:TextStyle(fontWeight:FontWeight.bold))),
  SwitchListTile(title:const Text('현재 위치 사용'),value:_p['use_current_location']??true,onChanged:(v)=>_set('use_current_location',v)),
  SwitchListTile(title:const Text('중간지점 계산에 위치 사용'),value:_p['use_location_for_midpoint']??true,onChanged:(v)=>_set('use_location_for_midpoint',v)),
  SwitchListTile(title:const Text('사진 위치로 장소 제안'),value:_p['use_photo_location']??true,onChanged:(v)=>_set('use_photo_location',v)),
  SwitchListTile(title:const Text('업로드 사진 위치정보 제거'),value:_p['strip_photo_metadata']??true,onChanged:(v)=>_set('strip_photo_metadata',v)),
  const Divider(),ListTile(leading:const Icon(Icons.logout),title:const Text('이 기기에서 로그아웃'),onTap:()=>_logout()),
  ListTile(leading:const Icon(Icons.devices),title:const Text('모든 기기에서 로그아웃'),onTap:()=>_logout(all:true)),
  ListTile(leading:const Icon(Icons.download),title:const Text('내 데이터 내려받기'),subtitle:const Text('JSON 형식으로 클립보드에 복사합니다.'),onTap:_export),
  const Divider(),ListTile(leading:const Icon(Icons.delete_forever,color:Colors.red),title:const Text('회원 탈퇴',style:TextStyle(color:Colors.red)),onTap:_withdraw),
 ]));
}
