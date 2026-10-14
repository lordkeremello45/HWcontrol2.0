import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'user_data_store.dart';

/// UI-only preferences, intentionally independent from hardware-control profiles.
class HWControlPersonalizationScreen extends StatefulWidget {
  const HWControlPersonalizationScreen({super.key, required this.store, required this.initialPreferences, this.onSaved});
  final HWControlUserDataStore store;
  final Map<String, dynamic> initialPreferences;
  final ValueChanged<Map<String, dynamic>>? onSaved;
  @override
  State<HWControlPersonalizationScreen> createState() => _HWControlPersonalizationScreenState();
}

class _HWControlPersonalizationScreenState extends State<HWControlPersonalizationScreen> {
  static const _schema = 1;
  static const _colours = <String, Color>{
    'teal': Color(0xFF64D8CB), 'blue': Color(0xFF5B9BFF), 'purple': Color(0xFFB58CFF),
    'red': Color(0xFFFF6B75), 'green': Color(0xFF6DD58C), 'orange': Color(0xFFFFB454), 'pink': Color(0xFFFF83C8),
  };
  static const _items = <String, String>{'cpu':'CPU','gpu':'GPU','memory':'Memory','storage':'Storage','temperatures':'Temperatures','fans':'Fans','graphs':'Live graphs','battery':'Battery'};
  late Map<String, dynamic> _p;
  late List<String> _order;
  final _hex = TextEditingController();
  final _name = TextEditingController();
  String? _status;
  @override
  void initState() {
    super.initState();
    _p = Map<String, dynamic>.from(widget.initialPreferences)..['personalizationSchema'] = _schema;
    const defaults = <String, dynamic>{
      'themeMode': 'dark', 'accentPreset': 'teal', 'customAccent': '#64D8CB',
      'cornerStyle': 'rounded', 'reduceMotion': false, 'temperatureUnit': 'celsius',
      'density': 'comfortable', 'fontScale': 1.0, 'uiSoundsEnabled': true,
      'animationSpeed': 1.0, 'startupPage': 'dashboard', 'graphRange': '5m',
      'uiProfiles': <String, dynamic>{},
    };
    for (final entry in defaults.entries) { _p.putIfAbsent(entry.key, () => entry.value); }
    for (final key in _items.keys) { _p.putIfAbsent('widget.' + key, () => true); }
    final raw = _p['dashboardOrder'];
    _order = raw is List ? raw.whereType<String>().where(_items.containsKey).toSet().toList() : _items.keys.toList();
    for (final k in _items.keys) { if (!_order.contains(k)) _order.add(k); }
    _hex.text = _s('customAccent', '#64D8CB');
  }
  @override
  void dispose() { _hex.dispose(); _name.dispose(); super.dispose(); }
  String _s(String k, String d) => _p[k] is String ? _p[k] as String : d;
  bool _b(String k, [bool d = false]) => _p[k] is bool ? _p[k] as bool : d;
  double _n(String k, double d) => _p[k] is num ? (_p[k] as num).toDouble() : d;
  Color? _parse(String v) {
    final s = v.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return null;
    return Color(0xFF000000 | int.parse(s, radix: 16));
  }
  Color get _accent => _s('accentPreset','teal') == 'custom' ? (_parse(_s('customAccent','#64D8CB')) ?? _colours['teal']!) : (_colours[_s('accentPreset','teal')] ?? _colours['teal']!);
  void _set(String k, Object v) => setState(() { _p[k] = v; _status = null; });
  Future<void> _save() async {
    final next = <String,dynamic>{..._p,'dashboardOrder':_order,'personalizationSchema':_schema};
    await widget.store.writeUiPreferences(next);
    if (!mounted) return;
    setState(() { _p = next; _status = 'Preferences saved.'; });
    widget.onSaved?.call(Map<String,dynamic>.from(next));
  }
  Future<void> _export() async {
    try {
      final json = const JsonEncoder.withIndent('  ').convert({'schema':_schema,'type':'hwcontrol-ui-preferences','preferences':{..._p,'dashboardOrder':_order}});
      final path = await FilePicker.platform.saveFile(dialogTitle:'Export preferences',fileName:'hwcontrol-ui-preferences.json',type:FileType.custom,allowedExtensions:['json'],bytes:utf8.encode('$json\n'));
      if (path != null && mounted) setState(() => _status = 'Preferences exported.');
    } catch (e) { if (mounted) setState(() => _status = 'Export failed: $e'); }
  }
  Future<void> _import() async {
    try {
      final pick = await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
      if (pick == null || pick.files.isEmpty) return;
      final f = pick.files.single;
      final bytes = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
      if (bytes == null || bytes.length > 1024*1024) throw const FormatException('File missing or larger than 1 MiB.');
      final doc = jsonDecode(utf8.decode(bytes));
      if (doc is! Map || doc['schema'] != _schema || doc['type'] != 'hwcontrol-ui-preferences' || doc['preferences'] is! Map) throw const FormatException('Unsupported preference document.');
      final p = Map<String,dynamic>.from(doc['preferences'] as Map);
      final accent = p['accentPreset'];
      if (accent is! String || (accent != 'custom' && !_colours.containsKey(accent))) throw const FormatException('Invalid accent preset.');
      final order = p['dashboardOrder'];
      if (order is! List || order.any((v) => v is! String || !_items.containsKey(v))) throw const FormatException('Invalid dashboard layout.');
      if (p['themeMode'] is! String || !const ['system', 'dark', 'light'].contains(p['themeMode'])) throw const FormatException('Invalid theme mode.');
      if (p['cornerStyle'] is! String || !const ['rounded', 'standard', 'sharp'].contains(p['cornerStyle'])) throw const FormatException('Invalid corner style.');
      if (p['temperatureUnit'] is! String || !const ['celsius', 'fahrenheit'].contains(p['temperatureUnit'])) throw const FormatException('Invalid temperature unit.');
      if (p['density'] is! String || !const ['compact', 'comfortable'].contains(p['density'])) throw const FormatException('Invalid density.');
      if (p['startupPage'] is! String || !const ['dashboard', 'controls', 'graphs'].contains(p['startupPage'])) throw const FormatException('Invalid startup page.');
      if (p['graphRange'] is! String || !const ['1m', '5m', '15m', '1h'].contains(p['graphRange'])) throw const FormatException('Invalid graph range.');
      final scale = p['fontScale'];
      final speed = p['animationSpeed'];
      if (scale is! num || !scale.isFinite || scale < 0.8 || scale > 1.5) throw const FormatException('Invalid text scale.');
      if (speed is! num || !speed.isFinite || speed < 0 || speed > 2) throw const FormatException('Invalid animation speed.');
      if (p['reduceMotion'] is! bool || p['uiSoundsEnabled'] is! bool) throw const FormatException('Invalid accessibility preferences.');
      for (final k in _items.keys) { if (p.containsKey('widget.' + k) && p['widget.' + k] is! bool) throw const FormatException('Invalid widget visibility preference.'); }
      setState(() {
        _p = p; _order = order.cast<String>().toSet().toList();
        for (final k in _items.keys) { if (!_order.contains(k)) _order.add(k); }
        _hex.text = _s('customAccent','#64D8CB');
        _status = 'Imported but not saved. Select Save to apply.';
      });
    } catch (e) { if (mounted) setState(() => _status = 'Import rejected: $e'); }
  }
  void _addProfile() {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 48) { setState(() => _status = 'Profile name must contain 1–48 characters.'); return; }
    final profiles = _p['uiProfiles'] is Map ? Map<String,dynamic>.from(_p['uiProfiles'] as Map) : <String,dynamic>{};
    profiles[name] = {..._p,'dashboardOrder':_order,'uiProfiles':<String,dynamic>{}};
    _p['uiProfiles'] = profiles; _name.clear();
    setState(() => _status = 'UI profile "$name" added; save to keep it.');
  }
  void _loadProfile(String name) {
    final profiles = _p['uiProfiles'];
    if (profiles is! Map || profiles[name] is! Map) return;
    final p = Map<String,dynamic>.from(profiles[name] as Map);
    setState(() {
      _p = {...p,'uiProfiles':profiles};
      final raw = p['dashboardOrder'];
      _order = raw is List ? raw.whereType<String>().where(_items.containsKey).toSet().toList() : _items.keys.toList();
      for (final k in _items.keys) { if (!_order.contains(k)) _order.add(k); }
      _hex.text = _s('customAccent','#64D8CB'); _status = 'Loaded "$name"; save to apply.';
    });
  }
  @override
  Widget build(BuildContext context) {
    final profiles = _p['uiProfiles'] is Map ? Map<String,dynamic>.from(_p['uiProfiles'] as Map) : <String,dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Personalization'),actions:[
        IconButton(tooltip:'Import',onPressed:_import,icon:const Icon(Icons.file_open_outlined)),
        IconButton(tooltip:'Export',onPressed:_export,icon:const Icon(Icons.file_download_outlined)),
      ]),
      body: ListView(padding:const EdgeInsets.all(20),children:[
        _section('Appearance',Icons.palette_outlined,[
          DropdownButtonFormField<String>(value:_s('themeMode','dark'),decoration:const InputDecoration(labelText:'Theme'),items:const[
            DropdownMenuItem(value:'system',child:Text('System default')),DropdownMenuItem(value:'dark',child:Text('Dark')),DropdownMenuItem(value:'light',child:Text('Light')),
          ],onChanged:(v){if(v!=null)_set('themeMode',v);}),
          const SizedBox(height:12),const Text('Accent colour'),
          Wrap(spacing:9,children:[
            for(final e in _colours.entries) InkWell(onTap:()=>_set('accentPreset',e.key),child:CircleAvatar(backgroundColor:e.value,child:_s('accentPreset','teal')==e.key?const Icon(Icons.check,color:Colors.black):null)),
            ChoiceChip(label:const Text('Custom'),selected:_s('accentPreset','teal')=='custom',onSelected:(_)=>_set('accentPreset','custom')),
          ]),
          TextField(controller:_hex,decoration:const InputDecoration(labelText:'Custom HEX (e.g. #64D8CB)'),onChanged:(v){if(_parse(v)!=null)_set('customAccent',v.startsWith('#')?v:'#$v');}),
          Row(children:[Container(width:26,height:26,decoration:BoxDecoration(color:_accent,shape:BoxShape.circle)),const SizedBox(width:10),const Text('Preview colour')]),
          DropdownButtonFormField<String>(value:_s('cornerStyle','rounded'),decoration:const InputDecoration(labelText:'Corner style'),items:const[
            DropdownMenuItem(value:'rounded',child:Text('Rounded')),DropdownMenuItem(value:'standard',child:Text('Standard')),DropdownMenuItem(value:'sharp',child:Text('Sharp')),
          ],onChanged:(v){if(v!=null)_set('cornerStyle',v);}),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Reduce motion'),value:_b('reduceMotion'),onChanged:(v)=>_set('reduceMotion',v)),
        ]),
        _section('Dashboard layout',Icons.dashboard_customize_outlined,[
          const Text('Reorder sections and toggle visibility.'),
          ReorderableListView(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),buildDefaultDragHandles:false,onReorder:(a,b){setState((){if(b>a)b--;final item=_order.removeAt(a);_order.insert(b,item);});},children:[
            for(var i=0;i<_order.length;i++) ListTile(key:ValueKey(_order[i]),leading:ReorderableDragStartListener(index:i,child:const Icon(Icons.drag_handle)),title:Text(_items[_order[i]]!),trailing:Switch(value:_b('widget.'+_order[i],true),onChanged:(v)=>_set('widget.'+_order[i],v))),
          ]),
          DropdownButtonFormField<String>(value:_s('graphRange','5m'),decoration:const InputDecoration(labelText:'Graph time range'),items:const[
            DropdownMenuItem(value:'1m',child:Text('1 minute')),DropdownMenuItem(value:'5m',child:Text('5 minutes')),DropdownMenuItem(value:'15m',child:Text('15 minutes')),DropdownMenuItem(value:'1h',child:Text('1 hour')),
          ],onChanged:(v){if(v!=null)_set('graphRange',v);}),
        ]),
        _section('Accessibility and behaviour',Icons.accessibility_new_outlined,[
          DropdownButtonFormField<String>(value:_s('temperatureUnit','celsius'),decoration:const InputDecoration(labelText:'Temperature unit'),items:const[
            DropdownMenuItem(value:'celsius',child:Text('Celsius (°C)')),DropdownMenuItem(value:'fahrenheit',child:Text('Fahrenheit (°F)')),
          ],onChanged:(v){if(v!=null)_set('temperatureUnit',v);}),
          DropdownButtonFormField<String>(value:_s('density','comfortable'),decoration:const InputDecoration(labelText:'Layout density'),items:const[
            DropdownMenuItem(value:'compact',child:Text('Compact')),DropdownMenuItem(value:'comfortable',child:Text('Comfortable')),
          ],onChanged:(v){if(v!=null)_set('density',v);}),
          Text('Text size: \${(_n('fontScale',1.0)*100).round()}%'),
          Slider(value:_n('fontScale',1.0).clamp(0.8,1.5).toDouble(),min:0.8,max:1.5,divisions:7,onChanged:(v)=>_set('fontScale',v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Interface sounds'),value:_b('uiSoundsEnabled',true),onChanged:(v)=>_set('uiSoundsEnabled',v)),
          Text('Animation speed: \${_n('animationSpeed',1.0).toStringAsFixed(1)}×'),
          Slider(value:_n('animationSpeed',1.0).clamp(0.0,2.0).toDouble(),min:0,max:2,divisions:4,onChanged:(v)=>_set('animationSpeed',v)),
          DropdownButtonFormField<String>(value:_s('startupPage','dashboard'),decoration:const InputDecoration(labelText:'Startup page'),items:const[
            DropdownMenuItem(value:'dashboard',child:Text('Dashboard')),DropdownMenuItem(value:'controls',child:Text('Controls')),DropdownMenuItem(value:'graphs',child:Text('Graphs')),
          ],onChanged:(v){if(v!=null)_set('startupPage',v);}),
        ]),
        _section('UI profiles',Icons.bookmarks_outlined,[
          const Text('Appearance-only profiles never modify hardware-control profiles.'),
          Row(children:[Expanded(child:TextField(controller:_name,maxLength:48,decoration:const InputDecoration(labelText:'New UI profile name'))),IconButton(onPressed:_addProfile,icon:const Icon(Icons.add_circle_outline))]),
          for(final name in profiles.keys.whereType<String>()) ListTile(title:Text(name),trailing:TextButton(onPressed:()=>_loadProfile(name),child:const Text('Load'))),
        ]),
        if(_status!=null) Padding(padding:const EdgeInsets.all(8),child:Text(_status!,style:TextStyle(color:_status!.startsWith('Import rejected')||_status!.startsWith('Export failed')?Theme.of(context).colorScheme.error:Theme.of(context).colorScheme.primary))),
        FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),
      ]),
    );
  }
  Widget _section(String title,IconData icon,List<Widget> children)=>Card(margin:const EdgeInsets.only(bottom:16),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Icon(icon,color:_accent),const SizedBox(width:10),Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700))]),
    const SizedBox(height:12),...children,
  ])));
}
