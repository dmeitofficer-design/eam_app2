import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// TODO: Adjust this import path if your Engineer model is located in a different directory
import '../../data/models/engineer.dart'; 

class EngineerDropdownSelector extends StatefulWidget {
  final String? initialValue;
  final Function(String?) onSelected;

  const EngineerDropdownSelector({
    super.key,
    this.initialValue,
    required this.onSelected,
  });

  @override
  State<EngineerDropdownSelector> createState() => _EngineerDropdownSelectorState();
}

class _EngineerDropdownSelectorState extends State<EngineerDropdownSelector> {
  String? _selectedId;
  List<Engineer> _availableEngineers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialValue;
    _getAvailableEngineers();
  }

  Future<void> _getAvailableEngineers() async {
    try {
      final data = await Supabase.instance.client
          .from('engineers')
          .select()
          .eq('is_available', true); // Fetch only currently free personnel
      
      if (mounted) {
        setState(() {
          _availableEngineers = (data as List)
              .map((e) => Engineer.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load engineers';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
            SizedBox(width: 12),
            Text(
              'Loading available engineers...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _getAvailableEngineers();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Assign Installation Engineer',
        hintText: 'Select an engineer',
      ),
      value: _selectedId,
      items: _availableEngineers.map((eng) {
        return DropdownMenuItem(
          value: eng.id, 
          child: Text(eng.name),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedId = val);
        widget.onSelected(val);
      },
    );
  }
}