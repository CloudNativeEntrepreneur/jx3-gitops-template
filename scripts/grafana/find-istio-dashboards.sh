WORKLOAD_DASHBOARD=7630
SERVICE_DASHBOARD=7636
MESH_DASHBOARD=7639
CONTROL_PLANE_DASHBOARD=7645
PERFORMANCE_DASHBOARD=11829

REVISION=46

curl -s https://grafana.com/api/dashboards/${WORKLOAD_DASHBOARD}/revisions/${REVISION}/download > helmfiles/monitor/charts/istio-dashboards/dashboards/istio-workload-dashboard.json
curl -s https://grafana.com/api/dashboards/${SERVICE_DASHBOARD}/revisions/${REVISION}/download > helmfiles/monitor/charts/istio-dashboards/dashboards/istio-service-dashboard.json
curl -s https://grafana.com/api/dashboards/${MESH_DASHBOARD}/revisions/${REVISION}/download > helmfiles/monitor/charts/istio-dashboards/dashboards/istio-mesh-dashboard.json
curl -s https://grafana.com/api/dashboards/${CONTROL_PLANE_DASHBOARD}/revisions/${REVISION}/download > helmfiles/monitor/charts/istio-dashboards/dashboards/istio-control-plane-dashboard.json
curl -s https://grafana.com/api/dashboards/${PERFORMANCE_DASHBOARD}/revisions/${REVISION}/download > helmfiles/monitor/charts/istio-dashboards/dashboards/istio-performance-dashboard.json
