// supabase/functions/recommend-places/index.ts
//
// 입력: { "lat": 37.43, "lng": 126.99, "radius_m": 1500 }
// 출력: { places: [{ name, address, lat, lng, category, distance_m }, ...] }
//
// 좌표 주변의 카페(CE7) / 음식점(FD6) / 놀거리(AT4 관광명소 + CT1 문화시설)를
// 카카오 로컬 API로 검색해서 카테고리별 상위 N개씩 묶어 반환한다.
// NearbyPlacesSheet과 ManualCourseBuilderScreen의 자동 채우기 둘 다 이 함수를 쓴다.

const KAKAO_REST_API_KEY = Deno.env.get("KAKAO_REST_API_KEY") ?? "";

const KAKAO_CATEGORY_CODES: Record<string, string[]> = {
  cafe: ["CE7"],
  restaurant: ["FD6"],
  attraction: ["AT4", "CT1"],
};

const PER_CATEGORY_LIMIT = 8; // 카테고리별로 최대 이만큼만 반환한다.
const KAKAO_PAGE_SIZE = 15; // 카카오 category search 1페이지 최대 개수.

interface KakaoDoc {
  id: string;
  place_name: string;
  address_name: string;
  road_address_name: string;
  x: string; // lng
  y: string; // lat
  distance: string; // meters (radius/x/y로 검색했을 때 채워짐)
}

async function kakaoCategorySearch(
  categoryCode: string,
  lat: number,
  lng: number,
  radius: number,
): Promise<KakaoDoc[]> {
  const url = new URL("https://dapi.kakao.com/v2/local/search/category.json");
  url.searchParams.set("category_group_code", categoryCode);
  url.searchParams.set("x", String(lng));
  url.searchParams.set("y", String(lat));
  url.searchParams.set("radius", String(radius));
  url.searchParams.set("size", String(KAKAO_PAGE_SIZE));
  url.searchParams.set("sort", "distance");

  const res = await fetch(url.toString(), {
    headers: { Authorization: `KakaoAK ${KAKAO_REST_API_KEY}` },
  });
  if (!res.ok) return [];
  const data = await res.json();
  return (data?.documents ?? []) as KakaoDoc[];
}

function toSuggestion(doc: KakaoDoc, category: string) {
  return {
    name: doc.place_name,
    address: doc.road_address_name || doc.address_name || "",
    lat: Number(doc.y),
    lng: Number(doc.x),
    category,
    distance_m: Number(doc.distance) || 0,
  };
}

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!KAKAO_REST_API_KEY) {
      return new Response(JSON.stringify({ error: "KAKAO_REST_API_KEY가 설정되지 않았습니다." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { lat, lng, radius_m } = await req.json();
    if (lat == null || lng == null) {
      return new Response(JSON.stringify({ error: "lat/lng가 필요합니다." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const radius = Math.min(Math.max(Number(radius_m) || 1500, 100), 20000); // 카카오 반경 제한(최대 20km) 내로 보정

    const results = await Promise.all(
      Object.entries(KAKAO_CATEGORY_CODES).map(async ([category, codes]) => {
        const docsPerCode = await Promise.all(
          codes.map((code) => kakaoCategorySearch(code, Number(lat), Number(lng), radius)),
        );
        const docs = docsPerCode.flat();

        // 같은 장소가 AT4/CT1처럼 여러 코드에 걸쳐 중복될 수 있으니 id로 dedupe.
        const seen = new Set<string>();
        const deduped = docs.filter((d) => {
          if (seen.has(d.id)) return false;
          seen.add(d.id);
          return true;
        });

        deduped.sort((a, b) => Number(a.distance) - Number(b.distance));
        return deduped.slice(0, PER_CATEGORY_LIMIT).map((d) => toSuggestion(d, category));
      }),
    );

    const places = results.flat();

    return new Response(JSON.stringify({ places }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});