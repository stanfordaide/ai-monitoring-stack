# AI Monitoring Stack

A comprehensive monitoring solution designed for AI inference workloads, providing real-time metrics, alerting, and observability across multiple time-series databases and visualization platforms.

## 🏗️ Architecture Overview

This monitoring stack combines multiple best-in-class tools to provide comprehensive observability:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AI Services   │    │  Batch Jobs     │    │   Applications  │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │    │  Pushgateway    │    │    Graphite     │
│  (Real-time)    │    │  (Batch jobs)   │    │ (Legacy/StatsD) │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 ▼
                    ┌─────────────────┐
                    │     Grafana     │
                    │  (Visualization) │
                    └─────────────────┘
                                 ▲
                    ┌─────────────────┐
                    │    InfluxDB     │
                    │ (SPC Metrics)   │
                    └─────────────────┘
```

## 🚀 Components

### Core Monitoring
- **[Grafana](https://grafana.com/)** - Unified visualization and dashboards
- **[Prometheus](https://prometheus.io/)** - Real-time metrics collection and alerting
- **[InfluxDB](https://www.influxdata.com/)** - Time-series database for detailed SPC metrics
- **[Graphite](https://graphiteapp.org/)** - Legacy metrics storage with StatsD support

### Supporting Services
- **[AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/)** - Alert routing and management
- **[Pushgateway](https://prometheus.io/docs/instrumenting/pushing/)** - Metrics gateway for batch jobs

## 📋 Prerequisites

- **Docker** (version 20.10 or higher)
- **Docker Compose** (version 2.0 or higher)
- **Root/sudo access** for installation
- **8GB+ RAM** recommended
- **20GB+ free disk space**

### Supported Platforms
- Ubuntu 20.04+ / Debian 11+
- CentOS 8+ / RHEL 8+
- macOS 12+ (for development)

## 🛠️ Quick Installation

1. **Clone or download** the monitoring stack files
2. **Run the installation script**:
   ```bash
   sudo ./install.sh
   ```

The installer will:
- ✅ Move all files to `/opt/monitoring`
- ✅ Create necessary bind mount directories
- ✅ Update configuration paths
- ✅ Set proper permissions
- ✅ Start the monitoring stack
- ✅ Display access information

## 🎯 Access Information

After installation, access the services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | admin / helloaide123 |
| **Prometheus** | http://localhost:9090 | - |
| **InfluxDB** | http://localhost:8086 | admin / helloaide123 |
| **AlertManager** | http://localhost:9093 | - |
| **Pushgateway** | http://localhost:9091 | - |

### Network Endpoints
| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Graphite Metrics | 2003-2004 | TCP | Carbon receiver |
| StatsD | 8125 | UDP | StatsD metrics |
| Graphite Admin | 8126 | TCP | Carbon admin |

## 🔧 Management

Use the monitoring manager script for easy operations:

```bash
cd /opt/monitoring

# Basic operations
./monitoring-manager.sh start      # Start all services
./monitoring-manager.sh stop       # Stop all services
./monitoring-manager.sh restart    # Restart all services
./monitoring-manager.sh status     # Check health status

# Monitoring
./monitoring-manager.sh logs                    # View all logs
./monitoring-manager.sh logs grafana           # View specific service
./monitoring-manager.sh logs prometheus -f     # Follow logs
./monitoring-manager.sh resources              # Resource usage

# Maintenance
./monitoring-manager.sh update     # Update and restart
./monitoring-manager.sh clean      # Clean old logs
./monitoring-manager.sh pull       # Pull latest images

# Backup & Restore
./monitoring-manager.sh backup                 # Create backup
./monitoring-manager.sh list-backups          # List backups
./monitoring-manager.sh restore <backup-path> # Restore from backup

# Information
./monitoring-manager.sh info       # Show access URLs
./monitoring-manager.sh help       # Show all commands
```

## 📊 Default Configuration

### Prometheus Configuration
- **Retention**: 15 days
- **Scrape interval**: 15 seconds
- **Evaluation interval**: 15 seconds
- **Admin API**: Enabled
- **Lifecycle API**: Enabled

### InfluxDB Configuration
- **Organization**: mercure-ai
- **Bucket**: ai-inference-spc
- **Token**: ai-inference-token-12345
- **Retention**: Default (infinite)

### Grafana Configuration
- **Plugins**: Pre-configured with explore traces, Loki explore, and metrics drilldown apps
- **Datasources**: Auto-provisioned for Prometheus, InfluxDB, and Graphite
- **Dashboards**: Auto-discovery from `/var/lib/grafana/dashboards`

## 🔍 Monitoring Your AI Services

### Prometheus Metrics (Real-time)
```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# Example AI inference metrics
inference_requests = Counter('ai_inference_requests_total', 'Total inference requests')
inference_duration = Histogram('ai_inference_duration_seconds', 'Inference duration')
model_accuracy = Gauge('ai_model_accuracy', 'Current model accuracy')

# Start metrics server
start_http_server(8000)
```

### InfluxDB Metrics (Detailed SPC)
```python
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

client = InfluxDBClient(url="http://localhost:8086", 
                       token="ai-inference-token-12345", 
                       org="mercure-ai")

# Write detailed metrics
point = Point("ai_inference") \
    .tag("model", "bert-large") \
    .tag("version", "v1.2") \
    .field("latency_p95", 245.7) \
    .field("accuracy", 0.94) \
    .field("confidence", 0.87)

write_api = client.write_api(write_options=SYNCHRONOUS)
write_api.write(bucket="ai-inference-spc", record=point)
```

### StatsD Metrics (Legacy/Simple)
```python
import statsd

# Simple StatsD client
stats = statsd.StatsClient('localhost', 8125)

# Send metrics
stats.incr('ai.inference.requests')
stats.timing('ai.inference.duration', 234)
stats.gauge('ai.model.accuracy', 94.5)
```

### Pushgateway (Batch Jobs)
```bash
# Push metrics from batch job
echo "ai_batch_job_duration_seconds 1234" | curl --data-binary @- \
    http://localhost:9091/metrics/job/ai-training/instance/worker-01
```

## 🚨 Alerting

### Prometheus Alert Rules
Alert rules are configured in `/opt/monitoring/config/prometheus/alert_rules.yml`:

```yaml
groups:
- name: ai_inference_alerts
  rules:
  - alert: HighInferenceLatency
    expr: ai_inference_duration_seconds > 1.0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High AI inference latency detected"
      
  - alert: LowModelAccuracy
    expr: ai_model_accuracy < 0.85
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "AI model accuracy below threshold"
```

### AlertManager Configuration
Configure notification channels in `/opt/monitoring/config/prometheus/alertmanager.yml`:

```yaml
route:
  group_by: ['alertname']
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://your-webhook-url'
```

## 📁 Directory Structure

```
/opt/monitoring/
├── docker-compose.yml              # Main compose file
├── monitoring-manager.sh           # Management script
├── config/                         # Configuration files
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── provisioning/
│   └── prometheus/
│       ├── prometheus.yml
│       ├── alert_rules.yml
│       └── alertmanager.yml
└── monitoring-binds/               # Persistent data
    ├── grafana/data/
    ├── prometheus/data/
    ├── influxdb/data/
    ├── alertmanager/data/
    ├── pushgateway/data/
    └── graphite/
        ├── conf/
        ├── storage/
        └── statsd_config/
```

## 🔧 Customization

### Adding Custom Dashboards
1. Place dashboard JSON files in `/opt/monitoring/config/grafana/dashboards/`
2. Restart Grafana: `./monitoring-manager.sh restart`

### Modifying Prometheus Targets
Edit `/opt/monitoring/config/prometheus/prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'my-ai-service'
    static_configs:
      - targets: ['localhost:8000']
    scrape_interval: 5s
```

### Custom Alert Rules
Add rules to `/opt/monitoring/config/prometheus/alert_rules.yml`:
```yaml
groups:
- name: custom_alerts
  rules:
  - alert: MyCustomAlert
    expr: my_metric > 100
    for: 1m
```

## 🐛 Troubleshooting

### Common Issues

**Port Conflicts**
```bash
# Check what's using the ports
sudo netstat -tlnp | grep -E ':(3000|9090|8086|9093|9091|2003|8125)'

# Stop conflicting services
sudo systemctl stop <service-name>
```

**Permission Issues**
```bash
# Fix ownership
sudo chown -R $USER:$USER /opt/monitoring
sudo chmod -R 755 /opt/monitoring
```

**Container Health Issues**
```bash
# Check container logs
./monitoring-manager.sh logs <service-name>

# Check container status
docker ps -a
docker inspect <container-name>
```

**Disk Space Issues**
```bash
# Check disk usage
./monitoring-manager.sh resources

# Clean up old data
./monitoring-manager.sh clean
docker system prune -af --volumes
```

### Service-Specific Issues

**Grafana**
- **Issue**: Dashboard not loading
- **Solution**: Check datasource connectivity in Grafana UI
- **Logs**: `./monitoring-manager.sh logs grafana`

**Prometheus**
- **Issue**: Targets not being scraped
- **Solution**: Verify target endpoints are accessible
- **Check**: http://localhost:9090/targets

**InfluxDB**
- **Issue**: Cannot connect with token
- **Solution**: Verify token in docker-compose.yml matches client configuration
- **Reset**: Delete `/opt/monitoring/monitoring-binds/influxdb/data` and restart

### Performance Tuning

**High Memory Usage**
```yaml
# Add to docker-compose.yml under service
deploy:
  resources:
    limits:
      memory: 2G
    reservations:
      memory: 1G
```

**High Disk Usage**
```bash
# Reduce Prometheus retention
# Edit prometheus command in docker-compose.yml
- '--storage.tsdb.retention.time=7d'

# Configure InfluxDB retention policy
influx bucket update --name ai-inference-spc --retention 168h
```

## 🔒 Security Considerations

### Production Deployment
1. **Change default passwords** in docker-compose.yml
2. **Configure TLS/SSL** for web interfaces
3. **Set up authentication** for Prometheus and other services
4. **Use secrets management** instead of environment variables
5. **Configure firewall rules** to restrict access

### Network Security
```yaml
# Example: Restrict Grafana to internal network
services:
  grafana:
    ports:
      - "127.0.0.1:3000:3000"  # Only localhost access
```

## 📈 Scaling

### Horizontal Scaling
- **Prometheus**: Use federation for multiple Prometheus instances
- **Grafana**: Deploy multiple Grafana instances behind load balancer
- **InfluxDB**: Use InfluxDB clustering (Enterprise feature)

### Vertical Scaling
```yaml
# Increase resources in docker-compose.yml
services:
  prometheus:
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '4'
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review container logs: `./monitoring-manager.sh logs`
3. Check service status: `./monitoring-manager.sh status`
4. Create an issue in the project repository

## 🔗 Useful Links

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [InfluxDB Documentation](https://docs.influxdata.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

---

**Happy Monitoring!** 🎉
