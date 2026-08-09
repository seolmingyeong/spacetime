import 'package:flutter/material.dart';
import '../../core/supabase_repository.dart';
import '../../models/models.dart';

class PersonalScheduleEditScreen extends StatefulWidget{
 final DateTime initialDate;final PersonalSchedule? item;
 const PersonalScheduleEditScreen({super.key,required this.initialDate,this.item});
 @override State<PersonalScheduleEditScreen> createState()=>_PersonalScheduleEditScreenState();
}
class _PersonalScheduleEditScreenState extends State<PersonalScheduleEditScreen>{
 late final TextEditingController _title,_memo;late DateTime _date;TimeOfDay? _time;late bool _allDay;bool _saving=false;
 @override void initState(){super.initState();final i=widget.item;_title=TextEditingController(text:i?.title);_memo=TextEditingController(text:i?.memo);_date=i?.scheduleDate??widget.initialDate;_allDay=i?.isAllDay??true;if(i?.scheduleTime!=null){final p=i!.scheduleTime!.split(':');_time=TimeOfDay(hour:int.parse(p[0]),minute:int.parse(p[1]));}}
 Future<void> _save()async{if(_title.text.trim().isEmpty)return;setState(()=>_saving=true);await SupabaseRepository().savePersonalSchedule(PersonalSchedule(id:widget.item?.id??'',title:_title.text,scheduleDate:_date,scheduleTime:_time==null?null:'${_time!.hour.toString().padLeft(2,'0')}:${_time!.minute.toString().padLeft(2,'0')}',isAllDay:_allDay,memo:_memo.text.trim()));if(mounted)Navigator.pop(context,true);}
 Future<void> _delete()async{if(widget.item==null)return;await SupabaseRepository().deletePersonalSchedule(widget.item!.id);if(mounted)Navigator.pop(context,true);}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.item==null?'개인 일정 추가':'개인 일정 수정'),actions:[if(widget.item!=null)IconButton(onPressed:_delete,icon:const Icon(Icons.delete_outline,color:Colors.red))]),body:ListView(padding:const EdgeInsets.all(20),children:[TextField(controller:_title,decoration:const InputDecoration(labelText:'제목',border:OutlineInputBorder())),const SizedBox(height:16),ListTile(tileColor:Colors.white,leading:const Icon(Icons.calendar_today),title:const Text('날짜'),subtitle:Text('${_date.year}.${_date.month}.${_date.day}'),onTap:()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2035),initialDate:_date);if(d!=null)setState(()=>_date=d);}),SwitchListTile(value:_allDay,onChanged:(v)=>setState(()=>_allDay=v),title:const Text('종일 일정')),if(!_allDay)ListTile(tileColor:Colors.white,leading:const Icon(Icons.schedule),title:const Text('시간'),subtitle:Text(_time?.format(context)??'시간 선택'),onTap:()async{final t=await showTimePicker(context:context,initialTime:_time??TimeOfDay.now());if(t!=null)setState(()=>_time=t);}),const SizedBox(height:16),TextField(controller:_memo,maxLines:4,decoration:const InputDecoration(labelText:'메모 (선택)',border:OutlineInputBorder())),const SizedBox(height:24),FilledButton(onPressed:_saving?null:_save,child:const Text('저장'))]));
}
