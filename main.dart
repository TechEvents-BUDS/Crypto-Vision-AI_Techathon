import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crypto Forecasting',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.blueGrey.shade50,
      ),
      home: const DataInputScreen(
        selectedCoin: 'bitcoin',
      ),
    );
  }
}

class DataInputScreen extends StatefulWidget {
  final String selectedCoin;

  const DataInputScreen({required this.selectedCoin});

  @override
  _DataInputScreenState createState() => _DataInputScreenState();
}

class _DataInputScreenState extends State<DataInputScreen> {
  final TextEditingController openController = TextEditingController();
  final TextEditingController highController = TextEditingController();
  final TextEditingController lowController = TextEditingController();
  final TextEditingController volumeController = TextEditingController();
  final TextEditingController marketCapController = TextEditingController();
  final TextEditingController userQueryController = TextEditingController();

  String predictedPrice = '0.00';
  String selectedCoin = 'bitcoin';
  String geminiAnswer = '';

  final List<String> coins = ['bitcoin', 'ethereum'];

  Future<void> predictPrice() async {
    if (_validateInputs()) {
      try {
        final response = await http.post(
          Uri.parse(
              'http://127.0.0.1:5000/predict'), // Update with your server IP
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'open': openController.text,
            'high': highController.text,
            'low': lowController.text,
            'volume': volumeController.text,
            'marketCap': marketCapController.text,
            'coin': selectedCoin,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            predictedPrice = data['predicted_closing_price'].toString();
          });
        } else {
          showErrorSnackbar(
              'Failed to fetch prediction. Status: ${response.statusCode}');
        }
      } catch (e) {
        showErrorSnackbar('Error predicting price: $e');
      }
    }
  }

  Future<void> getGeminiAnswer() async {
    final String apiKey =
        "AIzaSyD7OWf0xiC8892LsXry7FaswhUvebNBioQ"; // Replace with your API Key

    try {
      final response = await sendRequestWithRetry(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey'),
        userQueryController.text,
      );

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Ensure response contains the generated content
        if (data != null &&
            data.containsKey('candidates') &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0].containsKey('content') &&
            data['candidates'][0]['content'].containsKey('parts')) {
          final String responseText =
              data['candidates'][0]['content']['parts'][0]['text'];
          setState(() {
            geminiAnswer = formatAnswerAsBulletPoints(responseText);
          });
        } else {
          showErrorSnackbar('Gemini API returned no generated content.');
        }
      } else {
        showErrorSnackbar(
            'Failed to get Gemini answer. Status: ${response?.statusCode ?? 'Unknown'}');
      }
    } catch (e) {
      showErrorSnackbar('Error getting Gemini answer: $e');
    }
  }

  Future<http.Response?> sendRequestWithRetry(Uri url, String query) async {
    int attempts = 0;
    while (attempts < 3) {
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": query}
                ]
              }
            ]
          }),
        );

        if (response.statusCode == 429) {
          attempts++;
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
        return response;
      } catch (e) {
        attempts++;
        if (attempts >= 3) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  String formatAnswerAsBulletPoints(String answer) {
    // Split the answer by any newlines or other delimiters (like periods)
    final List<String> lines = answer.split(RegExp(r'(\.|\n)+'));

    // Remove empty lines and format the remaining lines with bullets
    return lines
        .where((line) => line.isNotEmpty)
        .map((line) => '• $line')
        .join('\n');
  }

  bool _validateInputs() {
    if (openController.text.isEmpty ||
        highController.text.isEmpty ||
        lowController.text.isEmpty ||
        volumeController.text.isEmpty ||
        marketCapController.text.isEmpty) {
      showErrorSnackbar('Please fill all input fields.');
      return false;
    }
    return true;
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Crypto Vision AI',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: selectedCoin,
              dropdownColor: Colors.black,
              style: TextStyle(color: Colors.white, fontSize: 16),
              underline: SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              items: coins.map((String coin) {
                return DropdownMenuItem<String>(
                  value: coin,
                  child: Text(coin.toUpperCase()),
                );
              }).toList(),
              onChanged: (String? newCoin) {
                setState(() {
                  selectedCoin = newCoin!;
                  predictedPrice =
                      '0.00'; // Reset predicted price on coin change
                });
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            buildTextField('Open Price', openController),
            SizedBox(height: 16),
            buildTextField('High Price', highController),
            SizedBox(height: 16),
            buildTextField('Low Price', lowController),
            SizedBox(height: 16),
            buildTextField('Volume', volumeController),
            SizedBox(height: 16),
            buildTextField('Market Cap', marketCapController),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: predictPrice,
              child: Text(
                'Predict',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Predicted Price: \$ $predictedPrice',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: userQueryController,
              decoration: InputDecoration(
                labelText: 'Ask Gemini AI',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: getGeminiAnswer,
              child: Text(
                'Send',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Gemini AI Answer:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              geminiAnswer,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        fillColor: Colors.white,
        filled: true,
      ),
      keyboardType: TextInputType.number,
    );
  }
}
