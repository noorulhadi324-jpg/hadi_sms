import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

final resultCardExamsProvider = FutureProvider.autoDispose<List<Map<String,dynamic>>>((ref) async {
  final c=SupabaseConfig.client; final sid=await ref.watch(schoolIdProvider.future); if(sid==null) return [];
  return List<Map<String,dynamic>>.from(await c.from('exams').select('*').eq('school_id',sid).order('exam_date',ascending:false));
});

final resultCardStudentsProvider = FutureProvider.autoDispose<List<Map<String,dynamic>>>((ref) async {
  final c=SupabaseConfig.client; final sid=await ref.watch(schoolIdProvider.future); if(sid==null) return [];
  return List<Map<String,dynamic>>.from(await c.from('students').select('id,full_name,admission_number,class_name,section_name').eq('school_id',sid).eq('is_active',true).order('full_name'));
});

final resultCardDataProvider = FutureProvider.autoDispose.family<Map<String,dynamic>, String>((ref,key) async {
  final parts=key.split(':'); final examId=int.parse(parts[0]); final studentId=int.parse(parts[1]);
  final c=SupabaseConfig.client; final sid=await ref.watch(schoolIdProvider.future); if(sid==null) throw Exception('School not linked.');
  final students=List<Map<String,dynamic>>.from(await c.from('students').select('*').eq('school_id',sid));
  final st=students.firstWhere((x)=>(x['id'] as num).toInt()==studentId,orElse:()=>{});
  final exams=List<Map<String,dynamic>>.from(await c.from('exams').select('*').eq('school_id',sid).eq('id',examId));
  final exam=exams.isEmpty?<String,dynamic>{}:exams.first;
  final results=List<Map<String,dynamic>>.from(await c.from('exam_results').select('*').eq('school_id',sid).eq('exam_id',examId));
  final examSubjects=List<Map<String,dynamic>>.from(await c.from('exam_subjects').select('*').eq('school_id',sid).eq('exam_id',examId));
  final subjectRows=List<Map<String,dynamic>>.from(await c.from('subjects').select('*').eq('school_id',sid));
  double obtained(Map<String,dynamic> r)=((r['obtained_marks'] as num?)?.toDouble()??0);
  double studentTotal(int id)=>results.where((r)=>(r['student_id'] as num).toInt()==id).fold(0.0,(a,r)=>a+obtained(r));
  final mine=results.where((r)=>(r['student_id'] as num).toInt()==studentId).toList();
  final className=(st['class_name']??'').toString(), section=(st['section_name']??'').toString();
  final classmates=students.where((s)=>(s['class_name']??'').toString()==className&&(s['section_name']??'').toString()==section).toList();
  final scores=classmates.map((s)=>studentTotal((s['id'] as num).toInt())).where((x)=>x>0).toList()..sort((a,b)=>b.compareTo(a));
  final total=examSubjects.fold(0.0,(a,s)=>a+((s['total_marks'] as num?)?.toDouble()??0)); final got=mine.fold(0.0,(a,r)=>a+obtained(r)); final pct=total>0?got/total*100:0;
  String grade(double p)=>p>=90?'A+':p>=80?'A':p>=70?'B':p>=60?'C':p>=50?'D':'F';
  final rows=mine.map((r){final es=examSubjects.firstWhere((x)=>(x['id'] as num).toInt()==(r['exam_subject_id'] as num).toInt(),orElse:()=>{});final sj=subjectRows.firstWhere((x)=>(x['id'] as num).toInt()==((es['subject_id'] as num?)?.toInt()??-1),orElse:()=>{});final tm=((es['total_marks'] as num?)?.toDouble()??0);final op=obtained(r);return {'subject':sj['name']??'Subject','obtained':op,'total':tm,'grade':r['grade']??grade(tm>0?op/tm*100:0),'remarks':r['remarks']??''};}).toList();
  return {'student':st,'exam':exam,'rows':rows,'obtained':got,'total':total,'percentage':pct,'grade':grade(pct),'position':got>0?scores.indexOf(got)+1:0,'className':className,'section':section};
});

class ResultCardScreen extends ConsumerStatefulWidget { const ResultCardScreen({super.key}); @override ConsumerState<ResultCardScreen> createState()=>_ResultCardScreenState(); }
class _ResultCardScreenState extends ConsumerState<ResultCardScreen>{int? examId,studentId;
  @override Widget build(BuildContext context){final ex=ref.watch(resultCardExamsProvider), st=ref.watch(resultCardStudentsProvider);return MainWrapper(child:ex.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>(Center(child:Text(e.toString()))),data:(exams)=>st.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>(Center(child:Text(e.toString()))),data:(students)=>_body(context,exams,students))));}
  Widget _body(BuildContext c,List<Map<String,dynamic>> exams,List<Map<String,dynamic>> students){return ListView(padding:const EdgeInsets.all(22),children:[const Text('Result Card',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Generate, preview and print the final student result card.'),const SizedBox(height:20),Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:300,child:DropdownButtonFormField<int>(value:examId,decoration:const InputDecoration(labelText:'Examination',border:OutlineInputBorder()),items:exams.map((e)=>DropdownMenuItem(value:(e['id'] as num).toInt(),child:Text(e['title'].toString()))).toList(),onChanged:(v)=>setState(()=>examId=v))),SizedBox(width:300,child:DropdownButtonFormField<int>(value:studentId,decoration:const InputDecoration(labelText:'Student',border:OutlineInputBorder()),items:students.map((s)=>DropdownMenuItem(value:(s['id'] as num).toInt(),child:Text(s['full_name'].toString()))).toList(),onChanged:(v)=>setState(()=>studentId=v)))]),const SizedBox(height:22),if(examId!=null&&studentId!=null)ref.watch(resultCardDataProvider('$examId:$studentId')).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>(Text(e.toString())),data:(d)=>_result(context,d))]);}
  Widget _result(BuildContext c,Map<String,dynamic>d){final st=d['student'] as Map<String,dynamic>;final rows=List<Map<String,dynamic>>.from(d['rows']);return Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Center(child:Column(children:[Text('RESULT CARD',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:AppColors.primary)),Text('${d['exam']['title']??'Examination'}',style:const TextStyle(fontWeight:FontWeight.w700))])),const Divider(height:30),Wrap(spacing:28,runSpacing:8,children:[Text('Student: ${st['full_name']}'),Text('Admission: ${st['admission_number']??'—'}'),Text('Class: ${d['className']} ${d['section']}'),Text('Position: ${d['position']>0?d['position']:'—'}')]),const SizedBox(height:18),Table(border:TableBorder.all(color:Colors.grey),children:[const TableRow(children:[Padding(padding:EdgeInsets.all(8),child:Text('Subject',style:TextStyle(fontWeight:FontWeight.bold))),Padding(padding:EdgeInsets.all(8),child:Text('Obtained')),Padding(padding:EdgeInsets.all(8),child:Text('Total')),Padding(padding:EdgeInsets.all(8),child:Text('Grade'))]),...rows.map((r)=>TableRow(children:[Padding(padding:const EdgeInsets.all(8),child:Text(r['subject'].toString())),Padding(padding:const EdgeInsets.all(8),child:Text(r['obtained'].toString())),Padding(padding:const EdgeInsets.all(8),child:Text(r['total'].toString())),Padding(padding:const EdgeInsets.all(8),child:Text(r['grade'].toString()))]))]),const SizedBox(height:18),Text('Total: ${d['obtained']} / ${d['total']}'),Text('Percentage: ${(d['percentage'] as num).toStringAsFixed(2)}%'),Text('Overall Grade: ${d['grade']}'),const SizedBox(height:18),Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:()=>_print(d),icon:const Icon(Icons.picture_as_pdf),label:const Text('Export / Print PDF')))])));}
  Future<void> _print(Map<String,dynamic>d)async{final doc=pw.Document();final st=d['student'] as Map<String,dynamic>;final rows=List<Map<String,dynamic>>.from(d['rows']);doc.addPage(pw.Page(pageFormat:PdfPageFormat.a4,build:(_)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Center(child:pw.Text('RESULT CARD',style:pw.TextStyle(fontSize:24,fontWeight:pw.FontWeight.bold))),pw.SizedBox(height:10),pw.Center(child:pw.Text('${d['exam']['title']??'Examination'}')),pw.SizedBox(height:15),pw.Text('Student: ${st['full_name']}'),pw.Text('Admission: ${st['admission_number']??'—'}'),pw.Text('Class: ${d['className']} ${d['section']}'),pw.Text('Position: ${d['position']>0?d['position']:'—'}'),pw.SizedBox(height:15),pw.Table.fromTextArray(headers:['Subject','Obtained','Total','Grade'],data:rows.map((r)=>[r['subject'].toString(),r['obtained'].toString(),r['total'].toString(),r['grade'].toString()]).toList()),pw.SizedBox(height:15),pw.Text('Total: ${d['obtained']} / ${d['total']}'),pw.Text('Percentage: ${(d['percentage'] as num).toStringAsFixed(2)}%'),pw.Text('Overall Grade: ${d['grade']}')]));final bytes=Uint8List.fromList(await doc.save());await Printing.layoutPdf(onLayout:(_)=>bytes);}
}