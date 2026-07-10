import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';

class CalculatorUI extends StatefulWidget {
  const CalculatorUI({super.key});

  @override
  State<CalculatorUI> createState() => _CalculatorUIState();
}

class _CalculatorUIState extends State<CalculatorUI> {
  String _display = '0';

  void _press(String value) {
    setState(() {
      if (_display == '0') {
        _display = value;
      } else {
        _display += value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calculator'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.bottomRight,
                child: Text(
                  _display,
                  style: const TextStyle(color: Colors.white, fontSize: 48),
                ),
              ),
            ),
            _buildButtonRow(['7', '8', '9']),
            _buildButtonRow(['4', '5', '6']),
            _buildButtonRow(['1', '2', '3']),
            _buildButtonRow(['0', '.', 'C']),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<String> values) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: values.map((value) {
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: ElevatedButton(
            onPressed: () {
              if (value == 'C') {
                setState(() => _display = '0');
              } else {
                _press(value);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 64),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      }).toList(),
    );
  }
}
