import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/models.dart';
import 'package:health_tracker/services/gemini_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client _clientReturning(String text, {int status = 200}) =>
    MockClient((request) async {
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': text}
                ]
              }
            }
          ]
        }),
        status,
      );
    });

void main() {
  group('extractJsonObject', () {
    test('parses a bare JSON object', () {
      expect(GeminiService.extractJsonObject('{"a": 1}'), '{"a": 1}');
    });

    test('strips a ```json fenced block', () {
      const raw = 'Sure, here you go:\n```json\n{"a": 1}\n```';
      expect(GeminiService.extractJsonObject(raw), '{"a": 1}');
    });

    test('ignores prose before/after the object', () {
      const raw = 'Here is the JSON: {"a": 1} — hope that helps!';
      expect(GeminiService.extractJsonObject(raw), '{"a": 1}');
    });

    test('throws when there is no JSON object at all', () {
      expect(() => GeminiService.extractJsonObject('not json at all'),
          throwsFormatException);
    });
  });

  group('parseVoiceMeal', () {
    test('returns structured fields for a well-formed response', () async {
      final service = GeminiService(
        client: _clientReturning('{"mealType":"lunch",'
            '"foodDescription":"Rice and dal",'
            '"items":["rice","dal"]}'),
      );
      final result = await service.parseVoiceMeal('rice and dal for lunch');
      expect(result, isNotNull);
      expect(result!.mealType, MealType.lunch);
      expect(result.foodDescription, 'Rice and dal');
      expect(result.items, ['rice', 'dal']);
    });

    test('unwraps a fenced JSON response', () async {
      final service = GeminiService(
        client: _clientReturning(
            '```json\n{"mealType":"breakfast","foodDescription":"Oats"}\n```'),
      );
      final result = await service.parseVoiceMeal('oats');
      expect(result?.foodDescription, 'Oats');
      expect(result?.items, isEmpty);
    });

    test('returns null on malformed JSON (caller falls back to raw text)',
        () async {
      final service =
          GeminiService(client: _clientReturning('not valid json at all'));
      final result = await service.parseVoiceMeal('mumbled words');
      expect(result, isNull);
    });

    test('returns null when foodDescription is missing', () async {
      final service =
          GeminiService(client: _clientReturning('{"mealType": "snack"}'));
      final result = await service.parseVoiceMeal('something');
      expect(result, isNull);
    });

    test('returns null on a network/HTTP error', () async {
      final service =
          GeminiService(client: _clientReturning('irrelevant', status: 500));
      final result = await service.parseVoiceMeal('anything');
      expect(result, isNull);
    });

    test('returns null for empty input without making a call', () async {
      var called = false;
      final service = GeminiService(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      final result = await service.parseVoiceMeal('   ');
      expect(result, isNull);
      expect(called, isFalse);
    });
  });

  group('suggestPantryDeductions', () {
    final pantry = [
      PantryItem(itemName: 'Rice', lastUpdated: 'now'),
      PantryItem(itemName: 'Dal', lastUpdated: 'now'),
      PantryItem(itemName: 'Eggs', lastUpdated: 'now'),
    ];

    test('returns only pantry-matching items flagged deplete:true', () async {
      final service = GeminiService(
        client: _clientReturning('{"deductions": ['
            '{"itemName": "Rice", "deplete": true},'
            '{"itemName": "Eggs", "deplete": false},'
            '{"itemName": "Ketchup", "deplete": true}'
            ']}'),
      );
      final result =
          await service.suggestPantryDeductions('Rice and eggs', pantry);
      expect(result, ['Rice']);
    });

    test('returns empty list on malformed JSON', () async {
      final service =
          GeminiService(client: _clientReturning('garbage response'));
      final result =
          await service.suggestPantryDeductions('Rice and dal', pantry);
      expect(result, isEmpty);
    });

    test('returns empty list for an empty pantry without calling out',
        () async {
      var called = false;
      final service = GeminiService(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      final result = await service.suggestPantryDeductions('Rice', const []);
      expect(result, isEmpty);
      expect(called, isFalse);
    });
  });
}
