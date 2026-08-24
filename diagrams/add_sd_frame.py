"""
Post-process PlantUML PNG:
  - Thêm khung SD bên ngoài (outer rectangle)
  - Pentagon tab nằm BÊN TRONG góc trên-trái của khung (chuẩn UML interaction frame)
"""

from PIL import Image, ImageDraw, ImageFont
import os


def add_sd_frame(input_png: str, output_png: str, title: str = "sd"):
    img = Image.open(input_png).convert("RGB")
    content_w, content_h = img.size

    # Padding ngoài khung (margin giữa khung và mép ảnh)
    pad_margin = 8
    # Padding trong khung (giữa khung và nội dung)
    pad_side   = 20
    pad_bottom = 20
    # Tab (pentagon) kích thước
    tab_h     = 26
    tab_notch = 11
    border_w  = 2

    # Font
    font = None
    for fp in ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/arial.ttf"]:
        if os.path.exists(fp):
            try:
                font = ImageFont.truetype(fp, 13)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    # Đo chữ để tính tab width
    bbox   = font.getbbox(title)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    tab_w  = text_w + 18

    # Canvas mới:
    #   width  = margin + border + pad_side + content + pad_side + border + margin
    #   height = margin + border + tab_h    + content + pad_bottom + border + margin
    new_w = pad_margin + border_w + pad_side   + content_w + pad_side   + border_w + pad_margin
    new_h = pad_margin + border_w + tab_h      + content_h + pad_bottom + border_w + pad_margin

    canvas = Image.new("RGB", (new_w, new_h), "white")

    # Dán nội dung: bắt đầu ngay bên dưới tab
    paste_x = pad_margin + border_w + pad_side
    paste_y = pad_margin + border_w + tab_h
    canvas.paste(img, (paste_x, paste_y))

    draw = ImageDraw.Draw(canvas)

    # Toạ độ khung ngoài
    fx1 = pad_margin
    fy1 = pad_margin
    fx2 = new_w - pad_margin
    fy2 = new_h - pad_margin

    # 1. Vẽ khung ngoài (hình chữ nhật đầy đủ)
    draw.line([(fx1, fy1), (fx2, fy1)], fill="black", width=border_w)  # trên
    draw.line([(fx1, fy1), (fx1, fy2)], fill="black", width=border_w)  # trái
    draw.line([(fx2, fy1), (fx2, fy2)], fill="black", width=border_w)  # phải
    draw.line([(fx1, fy2), (fx2, fy2)], fill="black", width=border_w)  # dưới

    # 2. Tô trắng vùng tab (xoá phần khung góc trên-trái bị tab che)
    tab_pts = [
        (fx1,                      fy1),
        (fx1 + tab_w - tab_notch,  fy1),
        (fx1 + tab_w,              fy1 + tab_notch),
        (fx1 + tab_w,              fy1 + tab_h),
        (fx1,                      fy1 + tab_h),
    ]
    draw.polygon(tab_pts, fill="white")

    # 3. Vẽ lại viền tab (đè lên nền trắng)
    # Cạnh trên tab = đoạn trên khung từ trái đến trước notch
    draw.line([(fx1, fy1), (fx1 + tab_w - tab_notch, fy1)],
              fill="black", width=border_w)
    # Đường chéo notch
    draw.line([(fx1 + tab_w - tab_notch, fy1), (fx1 + tab_w, fy1 + tab_notch)],
              fill="black", width=border_w)
    # Cạnh phải tab (từ notch xuống đáy tab)
    draw.line([(fx1 + tab_w, fy1 + tab_notch), (fx1 + tab_w, fy1 + tab_h)],
              fill="black", width=border_w)
    # Cạnh dưới tab (đường ngang phân tách bên trong khung)
    draw.line([(fx1, fy1 + tab_h), (fx1 + tab_w, fy1 + tab_h)],
              fill="black", width=border_w)
    # Cạnh trái tab = đoạn trái khung từ trên xuống đáy tab
    draw.line([(fx1, fy1), (fx1, fy1 + tab_h)],
              fill="black", width=border_w)

    # 4. Vẽ chữ bên trong tab
    text_x = fx1 + 7
    text_y = fy1 + (tab_h - text_h) // 2 - 1
    draw.text((text_x, text_y), title, fill="black", font=font)

    canvas.save(output_png, dpi=(150, 150))
    print(f"[add_sd_frame] Saved -> {output_png}  ({new_w}x{new_h}px)")


if __name__ == "__main__":
    base     = r"c:\Users\Admin\Desktop\KLTN\diagrams"
    seq_dir  = os.path.join(base, "Sequences")

    # input filename → SD frame title
    diagrams = [
        ("UC00_DangNhapAdmin.png",       "sd  UC00 – Đăng nhập Admin"),
        ("UC01_XacThucOTP_Analysis.png", "sd  UC01 – Xác thực OTP"),
        ("UC02_GuiSOS.png",              "sd  UC02 – Gửi yêu cầu SOS"),
        ("UC03_TheodoiCa.png",           "sd  UC03 – Theo dõi ca cứu hộ"),
        ("UC04_DongHuyCaSOS.png",        "sd  UC04 – Đóng / Hủy ca SOS"),
        ("UC05_XemLichSu.png",           "sd  UC05 – Xem lịch sử SOS"),
        ("UC06_DangKyTNV.png",           "sd  UC06 – Đăng ký TNV với eKYC"),
        ("UC07_LocDsSOS.png",            "sd  UC07 – Lọc danh sách ca SOS"),
        ("UC08_NhanCaCuuHo.png",         "sd  UC08 – Nhận ca cứu hộ"),
        ("UC09_XemLichSuTNV.png",        "sd  UC09 – Xem lịch sử cứu hộ (TNV)"),
        ("UC10_DuyetHoSoTNV.png",        "sd  UC10 – Duyệt hồ sơ TNV"),
        ("UC11_LienLac.png",             "sd  UC11 – Liên lạc trong ca cứu hộ"),
        ("UC12_TheodoiHanhTrinh.png",    "sd  UC12 – Theo dõi hành trình cứu hộ"),
    ]

    for filename, title in diagrams:
        src = os.path.join(base, filename)
        dst = os.path.join(seq_dir, filename)
        if os.path.exists(src):
            # Áp dụng SD frame rồi lưu thẳng vào Sequences/
            add_sd_frame(src, dst, title=title)
            # Xóa file thô trong diagrams/
            os.remove(src)
            print(f"[add_sd_frame] Removed raw PNG: {filename}")
        else:
            print(f"[add_sd_frame] Skipped (not found): {filename}")
