import http from 'k6/http';
import { check, sleep } from 'k6';


export const options = {
vus: 10,
duration: '30m',
thresholds: {
http_req_failed: ['rate<0.01'],
http_req_duration: ['p(95)<700'],
},
};


const BASE_URL = __ENV.BASE_URL || 'https://whoami.example.com';


export default function () {
const res = http.get(BASE_URL);
check(res, { 'status is 200': (r) => r.status === 200 });
sleep(1);
}