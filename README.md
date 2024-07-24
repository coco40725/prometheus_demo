# Prometheus 和 Grafana super easy Demo
本專案為示範使用 quarkus 搭配 docker 建立 Prometheus 和 Grafana 簡易監控系統的流程。

## Requirements
- Docker
- Quarkus

## Getting Started
### 1. 建立 docker-compose.yml
需要使用的服務有 
- app: quarkus 應用程式
- mongodb: 資料庫
- prometheus: 監控系統
- renderer: Grafana 圖表渲染器
- grafana: 監控視覺化
```yaml
version: '3.8'
services:
  app:
    image: prometheus_demo
    ports:
      - '8080:8080'
    depends_on:
      - mongodb

  mongodb:
    image: mongo
    container_name: mongodb
    restart: always
    ports:
      - '27017:27017'

  prometheus:
    image: prom/prometheus:v2.35.0
    container_name: prometheus
    user: root
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--web.route-prefix=/test'
      - '--web.external-url=http://localhost:9090/test'
    ports:
      - '9090:9090'

  renderer:
    image: grafana/grafana-image-renderer:3.4.2
    environment:
      BROWSER_TZ: Asia/Taipei
    ports:
      - '8081:8081'

  grafana:
    image: grafana/grafana-enterprise
    container_name: grafana
    environment:
      GF_RENDERING_SERVER_URL: http://renderer:8081/render
      GF_RENDERING_CALLBACK_URL: http://grafana:3000/
      GF_LOG_FILTERS: rendering:debug
    depends_on:
      - prometheus
      - renderer
    ports:
      - '3000:3000'

```


### 2. 建立 prometheus.yaml
用於設定監控系統的設定檔，可以設定抓取頻率、評估頻率、告警規則、蒐集資料的來源等。

這裡有個常犯錯的地方:
 **targets: ["localhost:8080]**， 這樣寫是錯誤的，因為 app 並沒有在 prometheus 的 container 裡面運行，所以應該要寫成 **targets: ["app:8080"]**，以導引到對應的 container 抓取 app 資料。
```yaml
global:
  scrape_interval: 5s # Server 抓取頻率
  evaluation_interval: 5s # Server 評估頻率
  external_labels:
    monitor: "my-monitor"
rule_files: #如何整併數據或建立告警條件
    - "alert.rules"
    - "nginx.rules"
scrape_configs: # 去哪邊蒐集資料
  - job_name: "prometheus"
    metrics_path: "/q/metrics"
    static_configs:
      - targets: ["app:8080"] #container name:port;

```

### 3. (option) 建立 test.sh
用於快速發送 request


### 4. 執行
```shell
# 建立 app image
docker build -f src/main/docker/Dockerfile.jvm -t prometheus_demo .

# 啟動服務
docker-compose up
```


### 5. 檢查服務是否順利啟動
- app: http://localhost:8080/example/prime/2 
  - 會回傳 "2 is not prime."
- quarkus metrics: http://localhost:8080/q/metrics
  - 可以看到 quarkus 的 metrics
  ```shell
    # HELP worker_pool_ratio Pool usage ratio
    # TYPE worker_pool_ratio gauge
    worker_pool_ratio{pool_name="vert.x-internal-blocking",pool_type="worker",} NaN
    worker_pool_ratio{pool_name="vert.x-worker-thread",pool_type="worker",} 0.005
    # HELP jvm_buffer_total_capacity_bytes An estimate of the total capacity of the buffers in this pool
    # TYPE jvm_buffer_total_capacity_bytes gauge
    jvm_buffer_total_capacity_bytes{id="mapped - 'non-volatile memory'",} 0.0
    jvm_buffer_total_capacity_bytes{id="mapped",} 0.0
    jvm_buffer_total_capacity_bytes{id="direct",} 1671199.0
    # HELP jvm_memory_committed_bytes The amount of memory in bytes that is committed for the Java virtual machine to use
    # TYPE jvm_memory_committed_bytes gauge
    ...
  ```
- prometheus: http://localhost:9090/targets
  - 檢查 Targets 是否都是 up
   
  ![target_up.png](images%2Ftarget_up.png)

- grafana: http://localhost:3000
  - 帳號: admin
  - 密碼: admin
  
  ![grafana_1.png](images%2Fgrafana_1.png)

### 6. 檢查 prometheus 是否有抓到資料
我們可以透過執行 ``test.sh`` 不斷地發送 request，然後到 prometheus 的 ``Graph`` 頁面查看是否有抓到資料。
我們選擇 ``http_server_requests_seconds_count`` 這個 metrics 來查看 request 數量。 

![prometheus_1.png](images%2Fprometheus_1.png)


### 7. 將資料匯入到 Grafana
- 建立 data source: (Connections -> Data Sources -> Add data source)

  指定資料的來源，這裡我們選擇 Prometheus。 HTTP 的 URL 設定 http://prometheus:9090

  ![prometheus_2.png](images%2Fprometheus_2.png)  

- 建立 dashboard: (Dashboards -> Create Dashboard)

  你可以選擇自己建立視覺化方式，或是直接引入別人設計好的。這裡我們先簡單自己建立一個。
  - 引入 data source
  
    ![prometheus_3_1.png](images%2Fprometheus_3_1.png)
  
  - 調整 query 條件
    
  - ![prometheus_3_2.png](images%2Fprometheus_3_2.png)

  - 完成的 dashboard
  
  ![prometheus_3.png](images%2Fprometheus_3.png)

### 8. 建立 Alert
- 建立 Contact points: (Alerts -> Contact points)
    
    指定告警訊息要發送到哪裡，支援 Email, Google Chat 等等，這裡我們使用 Google Chat。
    
    ![contact_point_1.png](images%2Fcontact_point_1.png)

- 指定 alert 條件 (Alerts -> Alert rules)
  
  這裡我們指定當 request status code 不是 200 時，就發送告警訊息。

  ![alert_rule_1.png](images%2Falert_rule_1.png)

   最後，我們可以透過觸發 404 來看 chat 是否有收到告警訊息。
  
   ![alert_rule_2.png](images%2Falert_rule_2.png)
