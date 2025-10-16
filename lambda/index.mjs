import https from 'https';

export const handler = async () => {
    const url = 'https://app.duleendra.com';

    const data = await new Promise((resolve, reject) => {
        const req = https.get(url, (res) => {
            let body = '';
            res.on('data', (chunk) => (body += chunk));
            res.on('end', () => resolve(body)); // <-- no JSON.parse()
        });
        req.on('error', reject);
    });

    console.log('Fetched response from app.duleendra.com:', data);

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'HTTP call success',
            responseText: data,
        }),
    };
};
