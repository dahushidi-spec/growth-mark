# ===== 构建阶段：Flutter Web =====
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# 先复制依赖清单，利用 Docker 层缓存
COPY frontend/pubspec.yaml frontend/pubspec.lock ./

RUN flutter pub get

# 复制前端源码
COPY frontend/ ./

# 构建 Web Release 版本
RUN flutter build web --release --no-tree-shake-icons

# 打补丁：替换 flutter_bootstrap.js 为兼容 dart2js 的自定义版本
RUN python3 -c "
import re
with open('build/web/flutter_bootstrap.js', 'r') as f:
    content = f.read()
with open('build/web/main.dart.js', 'r') as f:
    main_js = f.read()

# 检查是否包含 didCreateEngineInitializer
if 'didCreateEngineInitializer' in main_js:
    print('main.dart.js references didCreateEngineInitializer - needs custom bootstrap')

    # Extract engine revision
    match = re.search(r'\"engineRevision\":\"([^\"]+)\"', content)
    engine_rev = match.group(1) if match else 'unknown'

    custom = f'''(function() {{
  window._flutter = window._flutter || {{}};
  window._flutter.loader = {{
    didCreateEngineInitializer: function(engineInitializer) {{
      if (engineInitializer && typeof engineInitializer.initializeEngine === 'function') {{
        engineInitializer.initializeEngine()
          .then(function(engine) {{ if (typeof engine.runApp === 'function') engine.runApp(); }})
          .catch(function(e) {{ console.error('Engine init failed:', e); }});
      }}
    }}
  }};
  _flutter.buildConfig = {{
    \"engineRevision\": \"{engine_rev}\",
    \"builds\": [{{\"compileTarget\": \"dart2js\", \"renderer\": \"canvaskit\", \"mainJsPath\": \"main.dart.js\"}}]
  }};
  var ckUrl = 'https://www.gstatic.com/flutter-canvaskit/' + engine_rev;
  window.flutterCanvasKitLoaded = (async function() {{
    if (window.flutterCanvasKit) return window.flutterCanvasKit;
    var m = await import(ckUrl + '/canvaskit.js');
    window.flutterCanvasKit = await m.default({{
      instantiateWasm: function(i, cb) {{
        WebAssembly.instantiateStreaming(fetch(ckUrl + '/canvaskit.wasm'), i)
          .then(function(r) {{ cb(r.instance, r.module); }});
        return {{}};
      }}
    }});
    return window.flutterCanvasKit;
  }})();
  window.flutterCanvasKitLoaded.then(function() {{
    var s = document.createElement('script'); s.src = 'main.dart.js';
    document.head.appendChild(s);
  }}).catch(function(e) {{
    var s = document.createElement('script'); s.src = 'main.dart.js';
    document.head.appendChild(s);
  }});
}})();
'''
    with open('build/web/flutter_bootstrap.js', 'w') as f:
        f.write(custom)
    print('Custom bootstrap written')
else:
    print('main.dart.js does not reference didCreateEngineInitializer - original bootstrap works')
"

# ===== 运行阶段：Nginx =====
FROM docker.m.daocloud.io/library/nginx:1.27-alpine

# 复制 Flutter Web 构建产物
COPY --from=builder /app/build/web /usr/share/nginx/html

# 复制 Nginx 配置（反向代理 /api → api:8000，SPA 路由兜底）
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
