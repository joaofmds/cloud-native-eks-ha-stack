import http from 'k6/http';
import { check, sleep } from 'k6';


export const options = {
vus: 2,
duration: '1m',
thresholds: {
http_req_failed: ['rate<0.01'],
http_req_duration: ['p(95)<500'],
},
};


const BASE_URL = __ENV.BASE_URL || 'https://whoami.example.com';


export default function () {
const res = http.get(BASE_URL);
check(res, {
'status is 200': (r) => r.status === 200,
'body contains address/pod': (r) => /address|pod/i.test(r.body),
});
sleep(1);
}