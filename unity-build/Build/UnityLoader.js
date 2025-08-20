// Unity WebGL加载器（示例文件）
var UnityLoader = (function () {
    var instantiate = function (containerid, buildJson, onProgress) {
        // 创建Unity实例对象
        var unityInstance = {
            Module: {
                onProgress: onProgress || function () {}
            },
            SetFullscreen: function () {
                if (unityInstance.container.requestFullscreen) unityInstance.container.requestFullscreen();
                else if (unityInstance.container.msRequestFullscreen) unityInstance.container.msRequestFullscreen();
                else if (unityInstance.container.mozRequestFullScreen) unityInstance.container.mozRequestFullScreen();
                else if (unityInstance.container.webkitRequestFullscreen) unityInstance.container.webkitRequestFullscreen();
            }
        };
        
        // 设置容器
        unityInstance.container = typeof containerid === "string" ? document.getElementById(containerid) : containerid;
        
        // 显示加载消息
        unityInstance.container.innerHTML = '<div class="webgl-content">' +
            '<div id="unityContainer" style="width: 800px; height: 600px"></div>' +
            '<div class="footer">' +
            '<div class="webgl-logo"></div>' +
            '<div class="fullscreen" onclick="unityInstance.SetFullscreen()"></div>' +
            '<div class="title">Unity WebGL 示例</div>' +
            '</div>' +
            '</div>';
        
        // 模拟加载过程
        var progress = 0;
        var interval = setInterval(function () {
            progress += 0.01;
            if (progress >= 1) {
                clearInterval(interval);
                
                // 显示"未找到实际Unity构建"消息
                unityInstance.container.innerHTML = '<div style="padding: 20px; background-color: #333; color: white; text-align: center; border-radius: 5px;">' +
                    '<h2>示例模式</h2>' +
                    '<p>这是一个示例页面。请使用以下命令更新实际的Unity WebGL构建:</p>' +
                    '<code style="background-color: #222; padding: 5px 10px; border-radius: 3px;">unity update /path/to/your/webgl/build</code>' +
                    '</div>';
            }
            
            if (unityInstance.Module.onProgress) {
                unityInstance.Module.onProgress(unityInstance, progress);
            }
        }, 100);
        
        return unityInstance;
    };
    
    return {
        instantiate: instantiate
    };
})();
