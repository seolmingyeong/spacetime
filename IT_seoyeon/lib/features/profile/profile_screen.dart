import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/supabase_client.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../notification/notification_screen.dart';
import 'friends_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_account_screen.dart';

class ProfileScreen extends StatefulWidget{const ProfileScreen({super.key});@override State<ProfileScreen> createState()=>ProfileScreenState();}
class ProfileScreenState extends State<ProfileScreen>{UserProfile? _profile;bool _loading=true;
 Future<void> reload()async{final p=await SupabaseRepository().getMyProfile();if(mounted)setState((){_profile=p;_loading=false;});}
 @override void initState(){super.initState();reload();}
 Future<void> _edit()async{final c=TextEditingController(text:_profile!.nickname);final value=await showDialog<String>(context:context,builder:(x)=>AlertDialog(title:const Text('닉네임 수정'),content:TextField(controller:c,maxLength:20,decoration:const InputDecoration(labelText:'닉네임')),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim()),child:const Text('저장'))]));if(value!=null&&value.length>=2){await SupabaseRepository().updateProfile(nickname:value);reload();}}
Future<void> _photo()async{
   final action=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.photo_library),title:const Text('갤러리에서 선택'),onTap:()=>Navigator.pop(c,'gallery')),ListTile(leading:const Icon(Icons.camera_alt),title:const Text('사진 촬영'),onTap:()=>Navigator.pop(c,'camera')),ListTile(leading:const Icon(Icons.account_circle),title:const Text('Google 계정 사진 사용'),onTap:()=>Navigator.pop(c,'google')),ListTile(leading:const Icon(Icons.delete_outline),title:const Text('기본 이미지로 변경'),onTap:()=>Navigator.pop(c,'clear'))])));
   if(action==null)return;
   final repo=SupabaseRepository();
   try{
     if(action=='clear'){
       await repo.updateProfile(nickname:_profile!.nickname,clearAvatar:true);
     }else if(action=='google'){
       final url=supabase.auth.currentUser?.userMetadata?['avatar_url']??supabase.auth.currentUser?.userMetadata?['picture'];
       if(url!=null)await repo.updateProfile(nickname:_profile!.nickname,avatarUrl:url.toString());
     }else{
       final f=await ImagePicker().pickImage(source:action=='camera'?ImageSource.camera:ImageSource.gallery,imageQuality:85,maxWidth:1024,maxHeight:1024);
       if(f!=null){
         final url=await repo.uploadAvatar(await f.readAsBytes(),'jpg');
         await repo.updateProfile(nickname:_profile!.nickname,avatarUrl:url);
       }
     }
     await reload();
     if(mounted){
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('프로필 사진이 변경되었습니다.')));
     }
   }catch(e){
     debugPrint('프로필 사진 변경 실패: $e');
     if(mounted){
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('저장 실패: $e')));
     }
   }
 }
 @override Widget build(BuildContext context){if(_loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));final p=_profile!;return Scaffold(appBar:AppBar(title:const Text('프로필'),actions:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationScreen())),icon:const Icon(Icons.notifications_none))]),body:ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[InkWell(onTap:_photo,child:Stack(children:[CircleAvatar(radius:38,backgroundImage:p.avatarUrl==null?null:NetworkImage(p.avatarUrl!),child:p.avatarUrl==null?Text(p.nickname.isEmpty?'?':p.nickname[0],style:const TextStyle(fontSize:24)):null),const Positioned(right:0,bottom:0,child:CircleAvatar(radius:12,child:Icon(Icons.camera_alt,size:13)))])),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.nickname,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text(p.email.isNotEmpty?p.email:(supabase.auth.currentUser?.email??''),style:const TextStyle(color:AppColors.textSecondary)),const SizedBox(height:5),OutlinedButton(onPressed:_edit,child:const Text('닉네임 수정'))]))]))),const SizedBox(height:16),_item(Icons.people_alt_outlined,'친구 관리','이메일로 찾기 · 요청 · 친구 목록',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const FriendsScreen()))),_item(Icons.notifications_outlined,'알림 설정','푸시·이메일·종류별 설정',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationSettingsScreen()))),_item(Icons.lock_outline,'개인정보 및 계정','공개 범위 · 로그아웃 · 회원 탈퇴',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PrivacyAccountScreen())))]));}
 Widget _item(IconData icon,String title,String sub,VoidCallback tap)=>Card(child:ListTile(leading:Icon(icon,color:AppColors.profile),title:Text(title),subtitle:Text(sub),trailing:const Icon(Icons.chevron_right),onTap:tap));
}
