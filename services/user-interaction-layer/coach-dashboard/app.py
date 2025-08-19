import streamlit as st
import requests

st.set_page_config(page_title="Coach Dashboard", layout="wide")
st.title("教练战术面板")

col1, col2 = st.columns(2)

with col1:
    st.subheader("球队战术建议（占位）")
    st.write("未来接入 tactics-planner-dnn 服务，展示战术建议与可视化")

with col2:
    st.subheader("最近规则统计（1小时）")
    try:
        resp = requests.get("http://stat-aggregator-sql:8010/events/rule/summary?hours_back=24", timeout=5)
        data = resp.json()
        if isinstance(data, list) and data:
            for item in data:
                st.write(f"规则={item['rule_type']} | 违规={item['violation_count']} 警告={item['warning_count']} 平均置信度={item['avg_confidence']:.2f}")
        else:
            st.write("暂无规则统计数据")
    except Exception as e:
        st.error(f"获取规则统计失败: {e}")
    st.subheader("球员疲劳监测（占位）")
    st.write("未来接入 fatigue-monitor-imu 服务，展示疲劳指数与告警")