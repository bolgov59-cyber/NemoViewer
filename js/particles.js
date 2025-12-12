// ================== МОДУЛЬ ЧАСТИЦ ==================
console.log('🌀 Загрузка модуля частиц...');

// Закрытая область видимости (не конфликтует с другими файлами)
(function() {
    'use strict';
    
    // ================== ПЕРЕМЕННЫЕ ==================
    let particleTrajectories = [];
    let currentParticleTime = 0;
    let particleAnimation = null;
    
    // ================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==================
    
    function getSafeElementValue(id, defaultValue) {
        const element = document.getElementById(id);
        return element && element.value !== undefined ? element.value : defaultValue;
    }
    
    function geographicToPixel(lon, lat, canvas) {
        const region = getSafeElementValue('regionSelect', 'wo');
        
        if (region === 'wo') {
            return {
                x: (lon + 180) * (canvas.width / 360),
                y: (90 - lat) * (canvas.height / 180)
            };
        } else {
            return {
                x: canvas.width / 2 + lon * (canvas.width / 720),
                y: canvas.height / 2 - lat * (canvas.height / 360)
            };
        }
    }
    
    function createTestParticles() {
        particleTrajectories = [];
        const count = 100;
        
        for (let i = 0; i < count; i++) {
            const points = [];
            for (let t = 0; t < 11; t++) {
                points.push([
                    Math.random() * 360 - 180,
                    Math.random() * 170 - 85,
                    0.2 + Math.random() * 0.3
                ]);
            }
            particleTrajectories.push({id: i, points: points});
        }
        
        console.log(`✅ Создано ${count} тестовых частиц`);
    }
    
    // ================== ОСНОВНЫЕ ФУНКЦИИ ==================
    
    async function loadAndShowParticles() {
        console.log('🌀 Загрузка траекторий частиц...');
        
        try {
            // Получаем параметры безопасно
            const date = getSafeElementValue('dateSelect', '2024-01-15');
            const region = getSafeElementValue('regionSelect', 'wo');
            const depthIndex = getSafeElementValue('particle-depth', '0');
            const particleCount = getSafeElementValue('particle-density', '1000');
            
            // Запрос к API
            const params = new URLSearchParams({
                date: date,
                depth_index: depthIndex,
                forecast_range: '240',
                region: region,
                particle_count: particleCount
            });
            
            const response = await fetch('/api/particles/trajectories?' + params.toString());
            const data = await response.json();
            
            if (data.success && data.trajectories) {
                particleTrajectories = data.trajectories;
                console.log(`✅ Загружено ${particleTrajectories.length} траекторий`);
                showParticles();
                startParticleAnimation();
            } else {
                throw new Error(data.error || 'Ошибка API');
            }
            
        } catch (error) {
            console.error('❌ Ошибка загрузки:', error);
            console.log('🔄 Использую тестовые данные...');
            createTestParticles();
            showParticles();
            startParticleAnimation();
        }
    }
    
    function showParticles() {
        const canvas = document.getElementById('particleCanvas');
        const modalImg = document.getElementById('modalImg');
        
        if (canvas && modalImg) {
            const rect = modalImg.getBoundingClientRect();
            canvas.width = rect.width;
            canvas.height = rect.height;
            canvas.style.display = 'block';
        }
        
        const particleModal = document.getElementById('particleModal');
        if (particleModal) {
            particleModal.style.display = 'block';
        }
        
        drawParticlesAtTime(currentParticleTime);
    }
    
    function hideParticles() {
        const canvas = document.getElementById('particleCanvas');
        if (canvas) {
            canvas.style.display = 'none';
            const ctx = canvas.getContext('2d');
            if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
        }
        
        const particleModal = document.getElementById('particleModal');
        if (particleModal) {
            particleModal.style.display = 'none';
        }
        
        stopParticleAnimation();
    }
    
    function drawParticlesAtTime(timeIndex) {
        const canvas = document.getElementById('particleCanvas');
        const ctx = canvas?.getContext('2d');
        
        if (!ctx || !particleTrajectories.length) return;
        
        // Очищаем
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Рисуем частицы
        particleTrajectories.forEach(traj => {
            if (traj.points && traj.points.length > timeIndex) {
                const point = traj.points[timeIndex];
                const coords = geographicToPixel(point[0], point[1], canvas);
                const speed = point[2] || 0.3;
                const radius = Math.max(2, Math.min(5, speed * 15));
                const hue = 240 - Math.min(240, speed * 200);
                
                ctx.beginPath();
                ctx.arc(coords.x, coords.y, radius, 0, Math.PI * 2);
                ctx.fillStyle = `hsla(${hue}, 100%, 60%, 0.7)`;
                ctx.fill();
            }
        });
        
        // Обновляем время
        const display = document.getElementById('particleTimeDisplay');
        if (display) {
            display.textContent = `Время: ${timeIndex * 24}ч (${timeIndex}/10)`;
        }
    }
    
    function startParticleAnimation() {
        if (particleAnimation) return;
        
        particleAnimation = setInterval(() => {
            currentParticleTime = (currentParticleTime + 1) % 11;
            drawParticlesAtTime(currentParticleTime);
        }, 500);
    }
    
    function stopParticleAnimation() {
        if (particleAnimation) {
            clearInterval(particleAnimation);
            particleAnimation = null;
        }
    }
    
    function setParticleTime(timeIndex) {
        currentParticleTime = Math.max(0, Math.min(10, timeIndex));
        drawParticlesAtTime(currentParticleTime);
        stopParticleAnimation();
    }
    
    // ================== ЭКСПОРТ ==================
    // Экспортируем ТОЛЬКО нужные функции в глобальную область
    window.Particles = {
        loadAndShowParticles,
        showParticles,
        hideParticles,
        startParticleAnimation,
        stopParticleAnimation,
        setParticleTime
    };
    
    console.log('✅ Модуль частиц загружен. Доступен как window.Particles');
    
})(); // Самовызывающаяся функция для изоляции
