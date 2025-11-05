import http from 'k6/http';
import { check, sleep } from 'k6';


export const options = {
stages: [
{ duration: '2m', target: 20 },
{ duration: '5m', target: 50 },
{ duration: '5m', target: 100 },
{ duration: '2m', target: 0 },
],
thresholds: {
http_req_failed: ['rate<0.02'],
http_req_duration: ['p(99)<1000', 'p(95)<500'],
},
};


const BASE_URL = __ENV.BASE_URL || 'https://whoami.example.com';


export default function () {
const res = http.get(BASE_URL);
check(res, {
'status is 200': (r) => r.status === 200,
});
// short think time to jitter load
sleep(Math.random() * 0.3);
}