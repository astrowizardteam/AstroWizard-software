import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/cities.dart';
import '../engine/models.dart';

/// Birth details: name (optional), date, time (to the second) and place.
/// The place is picked by name from the built-in atlas (latitude, longitude
/// and time zone fill in automatically); coordinates can optionally be typed.
class InputScreen extends StatefulWidget {
  /// When given, the form opens pre-filled (edit mode).
  final BirthData? initial;
  const InputScreen({super.key, this.initial});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _placeText = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _tz = TextEditingController(text: '5.5');
  final _hh = TextEditingController(text: '12');
  final _mm = TextEditingController(text: '00');
  final _ss = TextEditingController(text: '00');

  City? _city;
  bool _manual = false;
  DateTime _date = DateTime(1995, 1, 1);

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    if (b == null) return;
    _name.text = b.name;
    _date = DateTime(b.wall.year, b.wall.month, b.wall.day);
    _hh.text = b.wall.hour.toString();
    _mm.text = b.wall.minute.toString().padLeft(2, '0');
    _ss.text = b.wall.second.toString().padLeft(2, '0');
    final match = CityDb.byName(b.place);
    if (match != null) {
      _city = match;
      _placeText.text = b.place;
    } else {
      _manual = true;
      _placeText.text = b.place.startsWith('Lat ') ? '' : b.place;
      _lat.text = b.latitude.toString();
      _lon.text = b.longitude.toString();
      _tz.text = b.tzHours.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _placeText, _lat, _lon, _tz, _hh, _mm, _ss]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _intValidator(String? v, int min, int max) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Number';
    if (n < min || n > max) return '$min-$max';
    return null;
  }

  String? _numValidator(String? v, double min, double max) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Number required';
    if (n < min || n > max) return '$min to $max';
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final double lat, lon, tz;
    final String place;
    if (_manual) {
      lat = double.parse(_lat.text);
      lon = double.parse(_lon.text);
      tz = double.parse(_tz.text);
      place = _placeText.text.trim().isEmpty
          ? 'Lat ${lat.toStringAsFixed(3)}, Lon ${lon.toStringAsFixed(3)}'
          : _placeText.text.trim();
    } else {
      final c = _city!;
      lat = c.lat;
      lon = c.lon;
      tz = c.tz;
      place = c.name;
    }
    final dt = DateTime.utc(_date.year, _date.month, _date.day,
        int.parse(_hh.text), int.parse(_mm.text), int.parse(_ss.text));
    Navigator.pop(
      context,
      BirthData(
        name: _name.text.trim(),
        wall: dt,
        tzHours: tz,
        latitude: lat,
        longitude: lon,
        place: place,
      ),
    );
  }

  Widget _placeField() {
    return Autocomplete<City>(
      initialValue: TextEditingValue(text: _placeText.text),
      displayStringForOption: (c) => c.name,
      optionsBuilder: (v) {
        return CityDb.search(v.text);
      },
      onSelected: (c) => setState(() {
        _city = c;
        _placeText.text = c.name;
      }),
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focus,
          onChanged: (t) {
            if (_city != null && _city!.name != t) setState(() => _city = null);
          },
          decoration: const InputDecoration(
            labelText: 'Place of birth (type city name)',
            prefixIcon: Icon(Icons.place_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            if (_manual) return null;
            if (_city == null) return 'Select a city from the list, or use "Enter coordinates"';
            return null;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'New Kundli' : 'Edit details')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text('Date of birth: ${DateFormat('dd MMM yyyy').format(_date)}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1800),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 12),
          Text('Time of birth (24-hour, local time)',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(children: [
            for (final f in [
              ('Hour', _hh, 23),
              ('Minute', _mm, 59),
              ('Second', _ss, 59),
            ]) ...[
              Expanded(
                child: TextFormField(
                  controller: f.$2,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: f.$1, border: const OutlineInputBorder()),
                  validator: (v) => _intValidator(v, 0, f.$3),
                ),
              ),
              if (f.$1 != 'Second') const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 12),
          if (!_manual) _placeField(),
          if (_city != null && !_manual)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Lat ${_city!.lat.toStringAsFixed(4)}, Lon ${_city!.lon.toStringAsFixed(4)}, '
                'UTC${_city!.tz >= 0 ? '+' : ''}${_city!.tz}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enter coordinates instead'),
            subtitle: const Text('For a place that is not in the list'),
            value: _manual,
            onChanged: (v) => setState(() => _manual = v),
          ),
          if (_manual) ...[
            TextFormField(
              controller: _placeText,
              decoration: const InputDecoration(labelText: 'Place name (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitude (N +)', border: OutlineInputBorder()),
                  validator: (v) => _numValidator(v, -90, 90),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lon,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitude (E +)', border: OutlineInputBorder()),
                  validator: (v) => _numValidator(v, -180, 180),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tz,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'UTC offset in hours (India = 5.5)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _numValidator(v, -12, 14),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: Text(widget.initial == null ? 'Generate Kundli' : 'Update'),
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          Text(
            'Ayanamsa: Lahiri  •  Rahu/Ketu: Mean node  •  Houses: whole-sign',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }
}
