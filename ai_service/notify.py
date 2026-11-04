from datetime import datetime

THRESHOLDS = {
    "pm2_5": [
        (15,  "tot",        "Không khí Tốt",         "Chất lượng không khí tốt, an toàn cho mọi người."),
        (25,  "trung_binh", "Mức Khá (Trung bình)",  "Chất lượng không khí ở mức khá, nhóm nhạy cảm cần chú ý."),
        (50,  "kem",        "Ô nhiễm Kém",           "Chất lượng không khí kém, hạn chế hoạt động ngoài trời."),
        (float("inf"), "xau", "Ô nhiễm Mức Cao",     "Chất lượng không khí ô nhiễm mức cao, ở trong nhà và đeo khẩu trang."),
    ]
}

HEALTH_MESSAGES = {
    "binh_thuong": {
        "tot":        "Chào ngày mới, không khí TP. Thủ Dầu Một trong lành, thuận lợi hoạt động ngoài trời.",
        "trung_binh": "Thông báo mức Khá: Không khí TP. Thủ Dầu Một ở ngưỡng trung bình khá, theo dõi khi ra ngoài lâu.",
        "kem":        "Cảnh báo ô nhiễm: Bụi mịn TP. Thủ Dầu Một ở mức kém, hãy đeo khẩu trang khi di chuyển.",
        "xau":        "Cảnh báo ô nhiễm mức Cao: Không khí TP. Thủ Dầu Một ở mức xấu, ưu tiên ở trong nhà và đeo KN95.",
    },
    "benh_ho_hap": {
        "tot":        "Chào ngày mới, không khí TP. Thủ Dầu Một trong lành, an toàn cho hệ hô hấp.",
        "trung_binh": "Thông báo mức Khá: Không khí TP. Thủ Dầu Một trung bình khá, người bệnh hô hấp và hen suyễn nhớ mang thuốc dự phòng.",
        "kem":        "Cảnh báo ô nhiễm: Bụi mịn TP. Thủ Dầu Một đang ở mức kém, hạn chế ra ngoài và vệ sinh mũi họng bằng nước muối.",
        "xau":        "Cảnh báo ô nhiễm mức Cao tại TP. Thủ Dầu Một: Người bệnh hô hấp ở trong nhà và đóng cửa sổ.",
    },
    "hen_suyen": {
        "tot":        "Chào ngày mới, không khí TP. Thủ Dầu Một trong lành, an toàn cho hệ hô hấp.",
        "trung_binh": "Thông báo mức Khá: Không khí TP. Thủ Dầu Một trung bình khá, người bệnh hô hấp và hen suyễn nhớ mang thuốc dự phòng.",
        "kem":        "Cảnh báo ô nhiễm: Bụi mịn TP. Thủ Dầu Một đang ở mức kém, hạn chế ra ngoài và vệ sinh mũi họng bằng nước muối.",
        "xau":        "Cảnh báo ô nhiễm mức Cao tại TP. Thủ Dầu Một: Người bệnh hô hấp ở trong nhà và đóng cửa sổ.",
    },
    "tre_em": {
        "tot":        "Chào ngày mới, không khí TP. Thủ Dầu Một rất tốt cho trẻ nhỏ và người cao tuổi dạo mát.",
        "trung_binh": "Thông báo mức Khá: Hạn chế để trẻ nhỏ và người lớn tuổi đứng gần trục đường đông xe tại Thủ Dầu Một.",
        "kem":        "Cảnh báo ô nhiễm: Bụi mịn TP. Thủ Dầu Một ở mức kém, không nên để trẻ em và người cao tuổi ra ngoài sáng sớm.",
        "xau":        "Cảnh báo ô nhiễm mức Cao tại TP. Thủ Dầu Một: Giữ trẻ nhỏ và người cao tuổi trong phòng thoáng sạch.",
    },
    "van_dong": {
        "tot":        "Chào ngày mới, thời điểm vàng tại TP. Thủ Dầu Một để chạy bộ, đạp xe và tập thể thao.",
        "trung_binh": "Thông báo mức Khá: Không khí TP. Thủ Dầu Một trung bình khá, nên ưu tiên tập thể thao trong công viên cây xanh.",
        "kem":        "Cảnh báo ô nhiễm: Bụi mịn TP. Thủ Dầu Một ở mức kém, hãy giảm cường độ cardio ngoài trời hoặc tập trong nhà.",
        "xau":        "Cảnh báo ô nhiễm mức Cao tại TP. Thủ Dầu Một: Tạm hoãn chạy bộ ngoài trời, đeo khẩu trang N95 có van thở khi ra đường.",
    },
}

def classify_pm25(pm25_value: float) -> str:
    for threshold, level, _, _ in THRESHOLDS["pm2_5"]:
        if pm25_value <= threshold:
            return level
    return "xau"

def get_status_label(level: str) -> str:
    for _, lv, label, _ in THRESHOLDS["pm2_5"]:
        if lv == level:
            return label
    return "Ô nhiễm Mức Cao"

def get_notification(pm25_value: float, health_group: str, min_fc: float = None, max_fc: float = None) -> dict:
    level = classify_pm25(pm25_value)
    status_label = get_status_label(level)
    messages = HEALTH_MESSAGES.get(health_group, HEALTH_MESSAGES["binh_thuong"])
    message = messages.get(level, "Theo dõi chất lượng không khí tại TP. Thủ Dầu Một.")

    low_val = min_fc if min_fc is not None else max(5.0, pm25_value * 0.78)
    high_val = max_fc if max_fc is not None else max(pm25_value * 1.18, pm25_value + 4.0)
    range_text = f"{low_val:.0f} - {high_val:.0f}"
    date_str = datetime.now().strftime("%d/%m")

    color_map = {
        "tot": "#4CAF50",
        "trung_binh": "#FFC107",
        "kem": "#FF9800",
        "xau": "#F44336",
    }

    return {
        "level": level,
        "status_label": status_label,
        "range_text": range_text,
        "date_line": f"{date_str} (Thủ Dầu Một - QCVN)",
        "color": color_map.get(level, "#9E9E9E"),
        "pm2_5": pm25_value,
        "message": message,
        "should_warn": level in ("trung_binh", "kem", "xau"),
    }
