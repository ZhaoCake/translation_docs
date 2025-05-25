#!/bin/bash

# 文档构建和部署助手脚本

case "$1" in
  serve)
    echo "启动本地预览服务器..."
    mkdocs serve
    ;;
  build)
    echo "构建静态站点..."
    mkdocs build
    echo "完成！生成的文件位于site目录中。"
    ;;
  deploy)
    echo "部署到GitHub Pages..."
    mkdocs gh-deploy
    echo "完成！网站已部署到GitHub Pages。"
    ;;
  docker-build)
    echo "构建Docker镜像..."
    docker build -t docs-mkdocs .
    echo "完成！可以使用 'docker run -p 8000:8000 docs-mkdocs' 启动文档服务器。"
    ;;
  docker-serve)
    echo "启动Docker容器中的文档服务器..."
    docker run --rm -it -p 8000:8000 -v $(pwd):/docs docs-mkdocs
    ;;
  *)
    echo "用法: $0 {serve|build|deploy|docker-build|docker-serve}"
    echo ""
    echo "命令:"
    echo "  serve         启动本地预览服务器"
    echo "  build         构建静态站点"
    echo "  deploy        部署到GitHub Pages"
    echo "  docker-build  构建Docker镜像"
    echo "  docker-serve  在Docker容器中启动服务器"
    exit 1
    ;;
esac

exit 0
