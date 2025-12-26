// public/static/js/main.js
import { ParticleSystem } from './particle-system/core.js';

// Глобальная переменная для доступа из консоли (для отладки)
window.particleSystem = null;

document.addEventListener('DOMContentLoaded', function() {
    console.log('📄 DOM загружен, инициализируем систему частиц...');
    
    // Ждём немного, чтобы все элементы точно загрузились
    setTimeout(() => {
        initializeParticleSystem();
    }, 500);
});

function initializeParticleSystem() {
    // 1. Проверяем, есть ли canvas для частиц
    const particleCanvas = document.getElementById('particleCanvas');
    
    if (!particleCanvas) {
        console.warn('⚠️ Canvas для частиц не найден. Создаём временный...');
        createTemporaryCanvas();
        return;
    }
    
    // 2. Создаём систему частиц
    window.particleSystem = new ParticleSystem('particleCanvas');
    
    // 3. Навешиваем обработчики на кнопки
    setupEventListeners();
    
    console.log('✅ Система частиц готова. Используйте window.particleSystem в консоли.');
}

function setupEventListeners() {
    // Кнопка старта
    const startBtn = document.getElementById('startParticlesBtn');
    if (startBtn) {
        startBtn.addEventListener('click', () => {
            if (window.particleSystem) {
                window.particleSystem.start();
            }
        });
    }
    
    // Кнопка остановки
    const stopBtn = document.getElementById('stopParticlesBtn');
    if (stopBtn) {
        stopBtn.addEventListener('click', () => {
            if (window.particleSystem) {
                window.particleSystem.stop();
            }
        });
    }
    
    // Тестовая кнопка (можно добавить в HTML для отладки)
    const testBtn = document.getElementById('testParticlesBtn');
    if (!testBtn) {
        // Создаём кнопку для отладки
        const debugDiv = document.createElement('div');
        debugDiv.style.position = 'fixed';
        debugDiv.style.top = '10px';
        debugDiv.style.right = '10px';
        debugDiv.style.zIndex = '10000';
        
        debugDiv.innerHTML = `
            <button id="debugStart" style="padding: 5px 10px; margin: 2px;">▶️ Старт</button>
            <button id="debugStop" style="padding: 5px 10px; margin: 2px;">⏹️ Стоп</button>
        `;
        
        document.body.appendChild(debugDiv);
        
        document.getElementById('debugStart').addEventListener('click', () => {
            if (window.particleSystem) window.particleSystem.start();
        });
        
        document.getElementById('debugStop').addEventListener('click', () => {
            if (window.particleSystem) window.particleSystem.stop();
        });
    }
}

function createTemporaryCanvas() {
    // Создаём временный canvas для тестирования
    const canvas = document.createElement('canvas');
    canvas.id = 'particleCanvas';
    canvas.style.position = 'absolute';
    canvas.style.top = '0';
    canvas.style.left = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.zIndex = '1000';
    canvas.style.pointerEvents = 'none'; // Чтобы клики проходили сквозь
    
    document.body.appendChild(canvas);
    
    // Переинициализируем
    setTimeout(() => {
        window.particleSystem = new ParticleSystem('particleCanvas');
        setupEventListeners();
    }, 100);
}
