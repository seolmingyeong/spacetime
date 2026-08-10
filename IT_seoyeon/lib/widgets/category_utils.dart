import 'package:flutter/material.dart';

class CategoryInfo {
  final IconData icon;
  final Color color;
  const CategoryInfo(this.icon, this.color);
}

/// 카카오 로컬 API의 category_group_code -> 아이콘/색상 매핑.
/// https://developers.kakao.com/docs/latest/ko/local/dev-guide#search-by-keyword-category-group-code
const Map<String, CategoryInfo> _kakaoCategoryMap = {
  'FD6': CategoryInfo(Icons.restaurant, Colors.orange), // 음식점
  'CE7': CategoryInfo(Icons.local_cafe, Colors.brown), // 카페
  'AD5': CategoryInfo(Icons.hotel, Colors.blue), // 숙박
  'AT4': CategoryInfo(Icons.attractions, Colors.green), // 관광명소
  'CT1': CategoryInfo(Icons.attractions, Colors.green), // 문화시설
  'MT1': CategoryInfo(Icons.shopping_bag, Colors.pink), // 대형마트
  'CS2': CategoryInfo(Icons.shopping_bag, Colors.pink), // 편의점
  'SW8': CategoryInfo(Icons.directions_bus, Colors.indigo), // 지하철역
  'BK9': CategoryInfo(Icons.account_balance, Colors.indigo), // 은행
  'HP8': CategoryInfo(Icons.local_hospital, Colors.red), // 병원
  'PM9': CategoryInfo(Icons.local_pharmacy, Colors.red), // 약국
  'PK6': CategoryInfo(Icons.local_parking, Colors.grey), // 주차장
  'OL7': CategoryInfo(Icons.local_gas_station, Colors.grey), // 주유소/충전소
};

CategoryInfo getCategoryInfo(String? type) {
  if (type == null) return CategoryInfo(Icons.place, Colors.grey);

  // 카카오 category_group_code는 대문자+숫자 2~3자리 형태 (예: CE7, FD6).
  final kakaoMatch = _kakaoCategoryMap[type];
  if (kakaoMatch != null) return kakaoMatch;

  // 하위 호환: 기존에 OSM 방식(type 문자열)으로 저장된 장소들을 위한 매칭.
  final t = type.toLowerCase();
  if (t.contains('restaurant') || t.contains('food') || t.contains('cafe') || t.contains('bakery')) {
    if (t.contains('cafe') || t.contains('bakery')) {
      return CategoryInfo(Icons.local_cafe, Colors.brown);
    }
    return CategoryInfo(Icons.restaurant, Colors.orange);
  }
  if (t.contains('hotel') || t.contains('hostel') || t.contains('apartment') || t.contains('guest_house') || t.contains('motel')) {
    return CategoryInfo(Icons.hotel, Colors.blue);
  }
  if (t.contains('attraction') || t.contains('museum') || t.contains('park') || t.contains('historic') || t.contains('tourism')) {
    return CategoryInfo(Icons.attractions, Colors.green);
  }
  if (t.contains('shop') || t.contains('mall') || t.contains('supermarket')) {
    return CategoryInfo(Icons.shopping_bag, Colors.pink);
  }
  if (t.contains('station') || t.contains('bus') || t.contains('airport') || t.contains('subway')) {
    return CategoryInfo(Icons.directions_bus, Colors.indigo);
  }

  return CategoryInfo(Icons.place, Colors.grey);
}