/**
 * KYC Controller
 * Proxy gọi FPT.AI ID Recognition API để nhận diện CCCD Việt Nam
 * API Key được giữ trên Backend, không lộ ra Mobile App.
 */

const https = require('https');
const http = require('http');

const FPT_API_KEY = process.env.FPT_EKYC_API_KEY || process.env.FPT_AI_API_KEY;
const FPT_ENDPOINT = 'https://api.fpt.ai/vision/idr/vnm';

/**
 * POST /api/kyc/recognize-id
 * Body: multipart/form-data với trường `image` (file ảnh CCCD)
 * Hoặc body JSON: { image: "<base64_string>" }
 *
 * Proxy request sang FPT.AI, trả về dữ liệu bóc tách:
 *   - id (Số CCCD)
 *   - name (Họ tên)
 *   - dob (Ngày sinh)
 *   - sex (Giới tính)
 *   - nationality (Quốc tịch)
 *   - home (Quê quán)
 *   - address (Địa chỉ thường trú)
 *   - doe (Ngày hết hạn)
 *   - type (Loại: chip/old/new)
 */
async function recognizeId(req, res) {
  try {
    if (!FPT_API_KEY) {
      return res.status(500).json({ error: 'FPT_AI_API_KEY chưa được cấu hình trên server.' });
    }

    // Xử lý ảnh từ base64 string (gửi từ Mobile App)
    const { image } = req.body;
    if (!image) {
      return res.status(400).json({ error: 'Thiếu ảnh CCCD (trường "image" dạng base64).' });
    }

    // Chuyển base64 thành Buffer
    const imageBuffer = Buffer.from(image, 'base64');

    // Tạo boundary cho multipart/form-data
    const boundary = '----FormBoundary' + Date.now().toString(16);
    const CRLF = '\r\n';

    // Tạo body multipart/form-data
    const bodyParts = [];
    bodyParts.push(`--${boundary}${CRLF}`);
    bodyParts.push(`Content-Disposition: form-data; name="image"; filename="cccd.jpg"${CRLF}`);
    bodyParts.push(`Content-Type: image/jpeg${CRLF}${CRLF}`);

    const headerBuffer = Buffer.from(bodyParts.join(''), 'utf-8');
    const footerBuffer = Buffer.from(`${CRLF}--${boundary}--${CRLF}`, 'utf-8');
    const multipartBody = Buffer.concat([headerBuffer, imageBuffer, footerBuffer]);

    // Gọi FPT.AI
    const url = new URL(FPT_ENDPOINT);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'api-key': FPT_API_KEY,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Content-Length': multipartBody.length,
      },
    };

    const fptResponse = await new Promise((resolve, reject) => {
      const protocol = url.protocol === 'https:' ? https : http;
      const fptReq = protocol.request(options, (fptRes) => {
        let data = '';
        fptRes.on('data', (chunk) => { data += chunk; });
        fptRes.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new Error('FPT.AI trả về dữ liệu không hợp lệ'));
          }
        });
      });
      fptReq.on('error', reject);
      fptReq.write(multipartBody);
      fptReq.end();
    });

    // Kiểm tra lỗi từ FPT.AI
    if (fptResponse.errorCode !== 0 && fptResponse.errorCode !== undefined) {
      console.error('[kycController] FPT.AI error:', JSON.stringify(fptResponse));
      return res.status(422).json({
        error: 'Không thể nhận diện CCCD. Vui lòng chụp lại ảnh rõ nét hơn.',
        fptError: fptResponse.errorMessage || fptResponse.message,
      });
    }

    // Trích xuất dữ liệu từ response FPT.AI
    // FPT.AI trả về mảng `data`, lấy phần tử đầu tiên
    const idData = fptResponse.data?.[0] || {};

    const result = {
      cccdNumber: idData.id || null,
      fullName: idData.name || null,
      dateOfBirth: idData.dob || null,
      sex: idData.sex || null,
      nationality: idData.nationality || null,
      placeOfOrigin: idData.home || null,
      placeOfResidence: idData.address || null,
      dateOfExpiry: idData.doe || null,
      cardType: idData.type_new || idData.type || null,
    };

    console.log(`[kycController] CCCD recognized: ${result.cccdNumber ? '****' + result.cccdNumber.slice(-4) : 'N/A'}`);
    res.status(200).json(result);
  } catch (err) {
    console.error('[kycController][recognizeId]', err.message);
    res.status(500).json({ error: 'Lỗi hệ thống khi gọi FPT.AI' });
  }
}

module.exports = { recognizeId };
