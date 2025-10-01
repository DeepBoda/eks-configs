import http from "k6/http";
import { check, sleep } from "k6";

const countries = [
  { slug: "italy", states: ["tuscany", "lazio", "campania", "sicily"] },
  { slug: "france", states: ["provence", "normandy", "brittany", "corsica"] },
  { slug: "spain", states: ["andalusia", "catalonia", "valencia", "balearic-islands"] },
  { slug: "greece", states: ["crete", "mykonos", "santorini", "rhodes"] },
  { slug: "portugal", states: ["algarve", "lisbon", "porto", "madeira"] },
  { slug: "india", states: ["goa", "kerala", "tamil-nadu", "maharashtra"] },
  { slug: "thailand", states: ["phuket", "krabi", "koh-samui", "pattaya"] },
  { slug: "japan", states: ["okinawa", "kanagawa", "shizuoka", "chiba"] },
  { slug: "australia", states: ["queensland", "new-south-wales", "victoria", "western-australia"] },
  { slug: "brazil", states: ["rio-de-janeiro", "bahia", "santa-catarina", "sao-paulo"] },
  { slug: "mexico", states: ["quintana-roo", "yucatan", "baja-california", "jalisco"] },
  { slug: "turkey", states: ["antalya", "mugla", "izmir", "mersin"] },
];

export let options = {
  scenarios: {
    stress_test: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "1m", target: 2000 },    // Gradual ramp up
        { duration: "2m", target: 5000 },    // Increase load
        { duration: "2m", target: 10000 },   // Peak load
        { duration: "1m", target: 0 },       // Ramp down
      ],
      gracefulRampDown: "30s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.1"],        // <10% errors (more realistic)
    http_req_duration: ["p(95)<5000"],    // 95% < 5s (increased for heavy load)
    http_req_duration: ["p(50)<2000"],    // 50% < 2s
  },
};

export default function () {
  const country = countries[Math.floor(Math.random() * countries.length)];
  const state = country.states[Math.floor(Math.random() * country.states.length)];
  
  // URL patterns with realistic distribution
  const urlPatterns = [
    () => "https://sandee.com/",                                    // 20% - Homepage
    () => `https://sandee.com/${country.slug}`,                    // 30% - Country pages
    () => `https://sandee.com/${country.slug}/${state}`,           // 40% - State pages
    () => `https://sandee.com/${country.slug}/${state}/beaches`,   // 10% - Beach listings
  ];
  
  // Weighted random selection
  const rand = Math.random();
  let url;
  if (rand < 0.2) url = urlPatterns[0]();
  else if (rand < 0.5) url = urlPatterns[1]();
  else if (rand < 0.9) url = urlPatterns[2]();
  else url = urlPatterns[3]();

  const params = {
    timeout: "30s",           // Reduced timeout
    headers: {
      "User-Agent": "K6-LoadTest/1.0",
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.5",
      "Accept-Encoding": "gzip, deflate",
      "Connection": "keep-alive",
    },
  };

  let res = http.get(url, params);

  check(res, {
    "status is 200": (r) => r && r.status === 200,
    "response time < 5s": (r) => r && r.timings.duration < 5000,
    "body contains content": (r) => r && r.body && r.body.length > 1000,
    "no server errors": (r) => r && r.status < 500,
  });

  // Realistic user behavior - vary sleep time
  const sleepTime = Math.random() * 2 + 0.5; // 0.5-2.5 seconds
  sleep(sleepTime);
}