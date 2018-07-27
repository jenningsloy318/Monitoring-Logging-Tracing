Prometheus Monitoring System
---

## 1. Components Choices

*  [telegraf](https://github.com/influxdata/telegraf) for node metrics, chose telegraf since it has more metrics than [node-exporter](https://github.com/prometheus/node_exporter), sucn as process monitor.
* [prometheus](https://github.com/prometheus/prometheus) for central monitor 
* [alertmanager](https://github.com/prometheus/alertmanager) to send out the alerts
* [grafana](https://github.com/grafana/grafana) to visulize the metrics as dashbords

## 2. Installation

There are plenty of documents describing the process of installation, so no details here

## 3. Configuration

if prometheus don't run on kubernetes or other platforms that has built-in service discovery, we'd also use   file_sd_configs as much as possible, since we only need to the the content of the file, then prometheus will auto reload it.

* file_sd_configs for alertermangers conf in `/etc/prometheus/prometheus.yml`

  ```yml
  alerting:
    alertmanagers:
    - file_sd_configs:
      - files: 
        - '/etc/prometheus/alertmanagers.yml'
  ```

  and in `/etc/prometheus/alertmanagers.yml`
  ```yml
  - targets:
    - localhost:9093
  ```
* file_sd_configs for job conf in `/etc/prometheus/prometheus.yml`
  ```yml
  - job_name: 'tegraf'
    metrics_path: /metrics
    file_sd_configs:
    - files: 
      - '/etc/prometheus/tgroups/telegraf-targets.yml'
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):.*'
        target_label: instance
        replacement: ${1}  ## this will remove the telegraf port numbuer of the label  instance
  ``` 

* labels in the `/etc/prometheus/tgroups/telegraf-targets.yml`

  we need define muliple labels to differentiate them 

  * env: to indentify the env of the target, can be dev/test/stating/prod 
  * type: to identify the type of the target, can be node/app/db
  * app: when type is app, to indentify the exact app name
  * service: to identify which service the targert is belong to
  * we can also add app label to node targets to identify what application is runnign on that node

  Examples:
  *  ` /etc/prometheus/tgroups/telegraf-targets.yml`
    ```yml
    - targets:
      - '172.18.70.29:9273'
      labels:
        type: 'node'
        env: 'test'
        app: 'jira'
        service: 'jira'
    ```
    *  ` /etc/prometheus/tgroups/telegraf-targets.yml`
    ```yml
    - targets:
      - '172.18.70.29:9104'
      labels:
        type: 'db'
        app: 'mysql'
        env: 'test'
        service: 'mysql'
    ```
    *  ` /etc/prometheus/tgroups/jira-targets.yml`
    ```yml
    - targets:
      - '172.18.69.215:8080'
      labels:
        type: 'app'
        app: 'jira'
        env: 'test'
        service: 'jira'
    ```
* alert rules and inhibit rules

  * when define alerts for the same metrics(e.g disk usage/CPU usage), different severity (high/warning/critical) has its individual alert, but with the same alertname, this can be used to inhibit the lower severity alerts when higer alerts triggered 
  
  Alert rule：
  ```yml
  - alert: High Disk Usage
    expr: disk_used_percent{fstype =~ "(xfs|ext3)" }  > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      description: 'Warning: {{$labels.host}}({{$labels.instance}}): Mount Point {{ $labels.path}}  is used above 85%,current value is: {{ $value }} .'
      summary: 'Warning: Low data disk space detected'

  - alert: High Disk Usage
    expr: disk_used_percent {fstype =~ "(xfs|ext3)" } > 95
    for: 5m
    labels:
      severity: critical
    annotations:
      description: 'Critical: {{$labels.host}}({{$labels.instance}}): Mount Point {{ $labels.path}}  is used above 90%,current value is: {{ $value }} .'
      summary: 'Critical: Low data disk space detected'
  ```
  inhibit rule (configured alertmanager conf `/etc/alertmanager/alertmanager.yml`)：
  ```
  inhibit_rules:
  - source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  equal: ['alertname', 'instance','job']
  ```
  *  if one instance is down, then inhibit all other alerts except the `instance down` alerts
    ```yml
    - source_match:
        alertname: 'Instance is Down'
      target_match:
        severity: 'critical'
      equal: [ 'instance']
    ```
* recievers in alertmanger
  
  * we can define smtp/slack/wechat paramter in global section of `/etc/alertmanager/alertmanager.yml`

  ```yml
  global:
    # smtp conf
    smtp_smarthost:  
    smtp_from:  
    smtp_require_tls:  
    smtp_auth_username: 
    smtp_auth_password:  

    # the slack Incoming WebHooks url
    slack_api_url:  

    # wechat conf
    wechat_api_url:  'https://qyapi.weixin.qq.com/cgi-bin/'
    wechat_api_secret:   # wechat application Secret
    wechat_api_corp_id:    # wechat corp id 
  ```
  * then we can define the recievers based on these conf 
  ```yml
  receivers:
  - name: 'email-receiver'
    email_configs:
    - send_resolved: true
      to:  'user@example.com'
      headers:
        From: user@example.com
        Subject: 'Alert: {{ template "email.default.subject" . }}'
  - name: 'wechat-reciever'
    wechat_configs:
    - send_resolved: true
      message: 'Alert: {{ template "wechat.default.message" . }}'
      to_user: ""
      to_party: "" # department id of contact
      to_tag: "" 
      agent_id: ""  # wechat application agentID
  - name: slack-reciever'
    slack_configs:
    - send_resolved: true
      channel: '#Alerts'
      title: "Alert: {{ .Status | toUpper }}  {{ .CommonAnnotations.summary }}\n"
      text: "{{range .Alerts }}\nDescription: {{ .Annotations.description }}\n{{ range .Labels.SortedPairs }} {{ .Name }}: {{ .Value }}\n{{end}}Metrics: <{{ .GeneratorURL}}| Click here>\n{{ end }}"
  ```
