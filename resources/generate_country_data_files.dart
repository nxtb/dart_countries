// we are going to take a base file and replace tokens with values that we
// extracted from the data source

import 'dart:convert';
import 'dart:io';

import 'package:dart_countries/src/models/phone_description.dart';

import 'data_sources/generate_countries_aggregated_info_json.dart';
import 'package:basic_utils/basic_utils.dart' show StringUtils;

import 'data_sources/read_country_info.dart';
import 'phone_encoder.dart';

const OUTPUT_PATH = 'lib/src/generated/';
const ISO_CODE_FILE = 'iso_codes.enum.dart';
const SRC = 'package:dart_countries/src';
const ISO_CODE_IMPORT = 'import "$SRC/generated/$ISO_CODE_FILE";';
final AUTO_GEN_COMMENT =
    '// This file was auto generated on ${DateTime.now().toIso8601String()}\n\n';
String generatedContent = '';

void main() async {
  final countriesInfo = await getCountryAggregatedInfo();
  await Future.wait([
    generateIsoCodeEnum(countriesInfo),
    generateCountryList(countriesInfo),
    generateIsoCodeConversionMap(countriesInfo),

    // iso code to property
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.name, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.native, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.capital, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.continent, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.currency, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.languages, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.flag, countriesInfo),
    generateIsoCodeToPropertyMapFile(CountryInfoKeys.dialCode, countriesInfo),
    generateIsoCodeToPropertyMapFile(
        CountryInfoKeys.phoneNumberLengths, countriesInfo),
    generatePhoneDescMapFile(countriesInfo),
    generateDialCodeMapFile(countriesInfo),
  ]);
  generateFile(fileName: 'generated.dart', content: generatedContent);
}

Future generateIsoCodeEnum(Map<String, dynamic> countries) {
  String content = 'enum IsoCode {';
  countries.keys.forEach((key) => content += '${key},');
  content += '}';
  return generateFile(fileName: ISO_CODE_FILE, content: content);
}

Future generateCountryList(Map countries) {
  String content = ISO_CODE_IMPORT + 'import "../models/country.dart";';
  content += 'const countries = [%%];';
  String body = '';
  countries.forEach((key, value) => body += 'Country(IsoCode.${key}),');
  content = content.replaceFirst('%%', body);
  return generateFile(fileName: 'countries.list.dart', content: content);
}

Future generateIsoCodeConversionMap(Map countries) {
  String content = ISO_CODE_IMPORT;
  content += 'const isoCodeConversionMap = {%%};';
  String body = '';
  countries.forEach((key, value) => body += '"${key}": IsoCode.${key},');
  content = content.replaceFirst('%%', body);
  return generateFile(
      fileName: 'iso_code_conversion.map.dart', content: content);
}

/// generates a map where the iso code is the key and the property is the value
Future generateIsoCodeToPropertyMapFile(
  String property,
  Map<String, dynamic> map,
) {
  final extractorFn = (countryInfo) => countryInfo[property];
  final newMap = Map.fromIterable(map.keys, value: (k) => extractorFn(map[k]));
  final fileName =
      'maps/countries_${StringUtils.camelCaseToLowerUnderscore(property)}.map.dart';
  String content = ISO_CODE_IMPORT +
      'const countries${property.substring(0, 1).toUpperCase()}${property.substring(1)} = {%%};';
  String body = '';
  newMap
      .forEach((key, value) => body += 'IsoCode.${key}: ${jsonEncode(value)},');
  content = content.replaceFirst('%%', body);
  return generateFile(fileName: fileName, content: content);
}

Future generateDialCodeMapFile(
  Map<String, dynamic> countries,
) {
  final dialCodeMap = toDialCodeMap(countries);
  final fileName = 'maps/countries_by_dial_code.map.dart';
  String content = ISO_CODE_IMPORT + 'const countriesByDialCode = {%%};';
  String body = '';
  dialCodeMap.forEach((key, value) =>
      body += '$key: [${value.map((v) => 'IsoCode.$v').join(',')}],');
  content = content.replaceFirst('%%', body);
  return generateFile(fileName: fileName, content: content);
}

Map<String, List> toDialCodeMap(Map<String, dynamic> countries) {
  final map = <String, List>{};
  countries.forEach((k, v) {
    if (map[v['dialCode']] == null) {
      map[v['dialCode']] = [];
    }
    // we insert the main country at the start of the array so it's easy to find
    if (v['phoneDescription']['isMainCountryForDialCode'] == true) {
      map[v['dialCode']]!.insert(0, k);
    } else {
      map[v['dialCode']]!.add(k);
    }
  });
  return map;
}

Future generatePhoneDescMapFile(Map countriesInfo) {
  String content =
      ISO_CODE_IMPORT + 'import "$SRC/models/phone_description.dart";';
  content += 'const countriesPhoneDescription = {%%};';
  String body = '';
  countriesInfo.forEach((key, value) {
    final desc =
        PhoneDescription.fromMap(value[CountryInfoKeys.phoneDescription]);
    body += 'IsoCode.$key: ${encodePhoneDescription(desc)},';
  });
  content = content.replaceFirst('%%', body);
  return generateFile(
    fileName: 'maps/countries_phone_description.map.dart',
    content: content,
  );
}

Future generateFile({
  required String fileName,
  required String content,
}) async {
  final file = await File(OUTPUT_PATH + fileName).create(recursive: true);
  content = AUTO_GEN_COMMENT + content;
  await file.writeAsString(content);
  generatedContent += 'export "$fileName";';
}
