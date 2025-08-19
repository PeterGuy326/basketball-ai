import streamlit as st
import requests
import base64

st.set_page_config(page_title="Referee UI", layout="wide")
st.title("裁判控制台")

col1, col2 = st.columns(2)

with col1:
    st.subheader("上传单帧检测")
    frame = st.file_uploader("选择一帧图像", type=["jpg", "jpeg", "png"])
    x = st.number_input("IMU X", value=0.0)
    y = st.number_input("IMU Y", value=0.0)
    z = st.number_input("IMU Z", value=0.0)
    if st.button("提交检测") and frame is not None:
        b64 = base64.b64encode(frame.read()).decode("utf-8")
        payload = {"video_frame": b64, "imu_data": [x, y, z]}
        try:
            resp = requests.post("http://travel-detector-svc:8001/travel-detection", json=payload, timeout=5)
            data = resp.json()
            st.success(f"走步: {data['is_travel']} | 置信度: {data['confidence']:.2f}")
        except Exception as e:
            st.error(f"请求失败: {e}")

with col2:
    st.subheader("实时检测事件")
    try:
        resp = requests.get("http://stat-aggregator-sql:8010/events/realtime?limit=10", timeout=5)
        data = resp.json()
        det = data.get("detections", [])
        rules = data.get("rules", [])
        st.write(f"最近检测事件: {len(det)} 条, 规则事件: {len(rules)} 条")
        if rules:
            for r in rules[:5]:
                st.write(f"[{r['timestamp']}] 规则={r.get('rule_type')} 决策={r.get('decision')} 置信度={r.get('confidence',0):.2f}")
        if det:
            for d in det[:5]:
                st.write(f"[{d['timestamp']}] 事件={d.get('event_type')} 置信度={d.get('confidence',0):.2f} 球员={d.get('player_id')}")
    except Exception as e:
        st.error(f"获取实时事件失败: {e}")