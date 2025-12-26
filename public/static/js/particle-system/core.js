// public/static/js/particle-system/core.js
console.log('🌀 Модуль системы частиц загружается...');

/**
 * Windy-style система частиц для визуализации течений
 */
export class ParticleSystem {
    constructor(canvasId) {
        console.log(`🎯 Создаём ParticleSystem для: ${canvasId}`);
        
        // 1. Находим canvas
        this.canvas = document.getElementById(canvasId);
        if (!this.canvas) {
            console.error(`❌ Canvas с id "${canvasId}" не найден!`);
            // Создаём временный canvas для отладки
            this.createDebugCanvas();
            return;
        }
        
        // 2. Настройка контекста
        this.ctx = this.canvas.getContext('2d');
        
        // 3. Инициализация состояния
        this.particles = [];
        this.isRunning = false;
        this.animationId = null;
        this.lastUpdateTime = 0;
        
        // 4. Настройка размеров
        this.updateCanvasSize();
        
        // 5. Конфигурация
        this.config = {
            maxParticles: 300,
            particleLifetime: 4.0, // секунды
            spawnRate: 80, // частиц в секунду
            baseSpeed: 0.0001,
            particleSize: 2.5
        };
        
        // 6. Тестовая отрисовка
        this.drawTestPattern();
        
        console.log('✅ ParticleSystem создан успешно!');
        console.log(`   Canvas: ${this.canvas.width}x${this.canvas.height}`);
    }
    
    /**
     * Создаёт временный canvas для отладки
     */
    createDebugCanvas() {
        console.warn('⚠️ Создаём временный debug canvas');
        
        this.canvas = document.createElement('canvas');
        this.canvas.id = 'particleCanvas';
        this.canvas.style.position = 'fixed';
        this.canvas.style.top = '20px';
        this.canvas.style.right = '20px';
        this.canvas.style.width = '400px';
        this.canvas.style.height = '300px';
        this.canvas.style.backgroundColor = 'rgba(0, 0, 0, 0.1)';
        this.canvas.style.border = '2px dashed #666';
        this.canvas.style.zIndex = '9999';
        
        document.body.appendChild(this.canvas);
        this.ctx = this.canvas.getContext('2d');
        
        // Сообщение на canvas
        this.ctx.fillStyle = 'red';
        this.ctx.font = '16px Arial';
        this.ctx.fillText('DEBUG CANVAS', 10, 30);
    }
    
    /**
     * Обновляет размеры canvas
     */
    updateCanvasSize() {
        const container = this.canvas.parentElement;
        if (container) {
            const rect = container.getBoundingClientRect();
            this.canvas.width = rect.width;
            this.canvas.height = rect.height;
        } else {
            this.canvas.width = 800;
            this.canvas.height = 600;
        }
        
        console.log(`📐 Canvas размер: ${this.canvas.width}x${this.canvas.height}`);
    }
    
    /**
     * Тестовая отрисовка (чтобы убедиться, что canvas работает)
     */
    drawTestPattern() {
        const ctx = this.ctx;
        const w = this.canvas.width;
        const h = this.canvas.height;
        
        // Фон
        ctx.fillStyle = 'rgba(240, 248, 255, 0.1)';
        ctx.fillRect(0, 0, w, h);
        
        // Рамка
        ctx.strokeStyle = 'rgba(0, 100, 200, 0.3)';
        ctx.lineWidth = 2;
        ctx.strokeRect(5, 5, w - 10, h - 10);
        
        // Текст
        ctx.fillStyle = '#0066cc';
        ctx.font = 'bold 18px Arial';
        ctx.fillText('NemoViewer Particle System', 20, 30);
        
        ctx.fillStyle = '#666';
        ctx.font = '14px Arial';
        ctx.fillText('Готов к запуску частиц', 20, 55);
        
        // Тестовые частицы
        for (let i = 0; i < 20; i++) {
            const x = 50 + Math.random() * (w - 100);
            const y = 80 + Math.random() * (h - 130);
            
            ctx.beginPath();
            ctx.arc(x, y, 3, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(0, 150, 255, ${0.3 + Math.random() * 0.5})`;
            ctx.fill();
        }
        
        console.log('🎨 Тестовая отрисовка завершена');
    }
    
    /**
     * Запуск системы частиц
     */
    async start() {
        if (this.isRunning) {
            console.warn('⚠️ Система уже запущена');
            return;
        }
        
        console.log('▶️ Запускаем систему частиц...');
        this.isRunning = true;
        
        // Инициализируем частицы
        await this.initializeParticles();
        
        // Запускаем анимационный цикл
        this.lastUpdateTime = performance.now();
        this.animate();
        
        // Обновляем интерфейс
        this.updateUI('started');
    }
    
    /**
     * Остановка системы
     */
    stop() {
        console.log('⏹️ Останавливаем систему частиц...');
        this.isRunning = false;
        
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }
        
        // Очищаем canvas
        this.clearCanvas();
        
        // Обновляем интерфейс
        this.updateUI('stopped');
    }
    
    /**
     * Инициализация частиц (пока тестовых)
     */
    async initializeParticles() {
        console.log('🔄 Инициализация частиц...');
        
        // Очищаем старые частицы
        this.particles = [];
        
        // Создаём тестовые частицы
        for (let i = 0; i < this.config.maxParticles * 0.3; i++) {
            this.particles.push(this.createParticle());
        }
        
        console.log(`✅ Создано ${this.particles.length} тестовых частиц`);
        return this.particles;
    }
    
    /**
     * Создание одной частицы
     */
    createParticle() {
        const w = this.canvas.width;
        const h = this.canvas.height;
        
        return {
            x: Math.random() * w,
            y: Math.random() * h,
            vx: (Math.random() - 0.5) * 2 * this.config.baseSpeed,
            vy: (Math.random() - 0.5) * 2 * this.config.baseSpeed,
            size: this.config.particleSize * (0.8 + Math.random() * 0.4),
            color: `rgba(${Math.floor(Math.random() * 100)}, 
                      ${Math.floor(150 + Math.random() * 100)}, 
                      255, 
                      ${0.5 + Math.random() * 0.3})`,
            age: 0,
            maxAge: this.config.particleLifetime * (0.7 + Math.random() * 0.6),
            life: 1.0
        };
    }
    
    /**
     * Анимационный цикл
     */
    animate() {
        const animateFrame = (currentTime) => {
            if (!this.isRunning) return;
            
            // Рассчитываем deltaTime
            const deltaTime = this.lastUpdateTime ? 
                (currentTime - this.lastUpdateTime) / 1000 : 0.016;
            this.lastUpdateTime = currentTime;
            
            // Обновляем и рисуем
            this.update(deltaTime);
            this.draw();
            
            // Следующий кадр
            this.animationId = requestAnimationFrame(animateFrame);
        };
        
        this.animationId = requestAnimationFrame(animateFrame);
    }
    
    /**
     * Обновление состояния частиц
     */
    update(deltaTime) {
        // Обновляем существующие частицы
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];
            
            // Старение
            p.age += deltaTime;
            p.life = 1.0 - (p.age / p.maxAge);
            
            // Удаляем старые частицы
            if (p.age > p.maxAge) {
                this.particles.splice(i, 1);
                continue;
            }
            
            // Движение
            p.x += p.vx * deltaTime * 60;
            p.y += p.vy * deltaTime * 60;
            
            // Отскок от границ
            if (p.x < 0 || p.x > this.canvas.width) p.vx *= -0.9;
            if (p.y < 0 || p.y > this.canvas.height) p.vy *= -0.9;
            
            // Ограничиваем координаты
            p.x = Math.max(0, Math.min(this.canvas.width, p.x));
            p.y = Math.max(0, Math.min(this.canvas.height, p.y));
        }
        
        // Добавляем новые частицы, если нужно
        const targetParticles = this.config.maxParticles;
        if (this.particles.length < targetParticles * 0.8) {
            const toAdd = Math.min(5, targetParticles - this.particles.length);
            for (let i = 0; i < toAdd; i++) {
                this.particles.push(this.createParticle());
            }
        }
    }
    
    /**
     * Отрисовка всех частиц
     */
    draw() {
        this.clearCanvas();
        
        // Рисуем каждую частицу
        for (const p of this.particles) {
            this.drawParticle(p);
        }
        
        // Информация
        this.drawStats();
    }
    
    /**
     * Отрисовка одной частицы
     */
    drawParticle(p) {
        const ctx = this.ctx;
        
        // Основной круг
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fillStyle = p.color.replace(')', `, ${p.life * 0.8})`).replace('rgb', 'rgba');
        ctx.fill();
        
        // Свечение (опционально)
        if (p.life > 0.5) {
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.size * 1.5, 0, Math.PI * 2);
            ctx.fillStyle = p.color.replace(')', `, ${p.life * 0.2})`).replace('rgb', 'rgba');
            ctx.fill();
        }
    }
    
    /**
     * Отображение статистики
     */
    drawStats() {
        const ctx = this.ctx;
        
        ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        ctx.fillRect(10, 10, 180, 65);
        
        ctx.fillStyle = 'white';
        ctx.font = '12px monospace';
        ctx.fillText(`Частиц: ${this.particles.length}`, 20, 30);
        ctx.fillText(`Состояние: ${this.isRunning ? 'Активно' : 'Остановлено'}`, 20, 50);
        ctx.fillText(`Canvas: ${this.canvas.width}x${this.canvas.height}`, 20, 70);
    }
    
    /**
     * Очистка canvas
     */
    clearCanvas() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
    
    /**
     * Обновление UI кнопок
     */
    updateUI(state) {
        const startBtn = document.getElementById('startParticlesBtn');
        const stopBtn = document.getElementById('stopParticlesBtn');
        
        if (startBtn && stopBtn) {
            if (state === 'started') {
                startBtn.disabled = true;
                stopBtn.disabled = false;
                startBtn.textContent = '▶️ Запущено';
                stopBtn.textContent = '⏹️ Остановить';
            } else {
                startBtn.disabled = false;
                stopBtn.disabled = true;
                startBtn.textContent = '▶️ Запустить частицы';
                stopBtn.textContent = '⏹️ Остановлено';
            }
        }
    }
}

// ================== ГЛОБАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ ==================

/**
 * Автоматическая инициализация при загрузке страницы
 */
function autoInitialize() {
    console.log('🔄 Автоинициализация системы частиц...');
    
    // Ждём загрузки DOM
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initOnReady);
    } else {
        setTimeout(initOnReady, 100);
    }
    
    function initOnReady() {
        // Ищем canvas
        const canvas = document.getElementById('particleCanvas');
        
        if (!canvas) {
            console.warn('⚠️ Canvas не найден, отложенная инициализация');
            // Будем проверять периодически
            setTimeout(initOnReady, 1000);
            return;
        }
        
        // Создаём систему
        window.particleSystem = new ParticleSystem('particleCanvas');
        console.log('✅ Система частиц инициализирована автоматически');
        
        // Находим кнопки и привязываем события
        setupEventListeners();
    }
    
    function setupEventListeners() {
        const startBtn = document.getElementById('startParticlesBtn');
        const stopBtn = document.getElementById('stopParticlesBtn');
        
        if (startBtn) {
            startBtn.addEventListener('click', () => {
                if (window.particleSystem) {
                    window.particleSystem.start();
                }
            });
            console.log('✅ Кнопка "Старт" привязана');
        }
        
        if (stopBtn) {
            stopBtn.addEventListener('click', () => {
                if (window.particleSystem) {
                    window.particleSystem.stop();
                }
            });
            console.log('✅ Кнопка "Стоп" привязана');
        }
    }
}

// Запускаем автоинициализацию
autoInitialize();

// Экспортируем для использования в других модулях
export default ParticleSystem;
console.log('✅ Модуль core.js полностью загружен и готов');
