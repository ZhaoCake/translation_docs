FROM python:3.9-slim

WORKDIR /docs

# 安装MkDocs和相关插件
RUN pip install --no-cache-dir mkdocs mkdocs-material

# 复制文档文件
COPY . .

# 暴露MkDocs开发服务器端口
EXPOSE 8000

# 默认命令：启动MkDocs开发服务器
CMD ["mkdocs", "serve", "--dev-addr=0.0.0.0:8000"]
