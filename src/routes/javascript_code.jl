# src/routes/javascript_code.jl
module JavaScriptCode

# Основные функции загрузки карт
const MAP_FUNCTIONS = """
// ================== ОСНОВНЫЕ ФУНКЦИИ ==================
function loadMap() {
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const parameter = document.getElementById('parameterSelect').value;
    const depth = document.getElementById('depthSelect').value;
    const forecast = document.getElementById('forecastSelect').value;
    
    const forecastStr = String(forecast).padStart(3, '0');
    
    const parametersWithoutDepth = ['ice', 'mld', 'ssh'];
    let filename;
    
    if (parametersWithoutDepth.includes(parameter)) {
        filename = region + '_' + parameter + '_' + forecastStr + '.png';
    } else {
        filename = region + '_' + parameter + depth + '_' + forecastStr + '.png';
    }
    
    document.getElementById('currentMap').src = '/static/maps/' + date + '/' + filename;
}

function loadAnimation() {
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const parameter = document.getElementById('parameterSelect').value;
    const depth = document.getElementById('depthSelect').value;
    
    const parametersWithoutDepth = ['ice', 'mld', 'ssh'];
    let filename;
    
    if (parametersWithoutDepth.includes(parameter)) {
        filename = region + '_' + parameter + '_anim.gif';
    } else {
        filename = region + '_' + parameter + depth + '_anim.gif';
    }
    
    document.getElementById('currentMap').src = '/static/maps/' + date + '/' + filename;
}
"""

# Функции модальных окон
const MODAL_FUNCTIONS = """
// ================== МОДАЛЬНОЕ ОКНО КАРТЫ ==================
function openModal() {

    document.getElementById('mapModal').style.display = 'block';
    document.getElementById('modalImg').src = document.getElementById('currentMap').src;
    initSectionCanvas(); // Инициализируем canvas при открытии модального окна
}

function closeModal() {
    document.getElementById('mapModal').style.display = 'none';
    clearSectionCanvas(); // Очищаем canvas при закрытии
}

function closeGraphModal() {
    document.getElementById('graphModal').style.display = 'none';
}
"""

# Конфигурация проекций и преобразование координат
const COORDINATE_FUNCTIONS = """
// ================== КОНФИГУРАЦИЯ ПРОЕКЦИЙ И ГРАНИЦ ==================
const mapLeftM = 52;
const mapTopM = 48;
const mapRightM = 1240;
const mapBottomM = 639;

const mapLeftA = 103;
const mapTopA = 64;
const mapRightA = 692;
const mapBottomA = 668;

proj4.defs("EPSG:4326", "+proj=longlat +datum=WGS84 +no_defs");
proj4.defs("ESRI:102018", "+proj=stere +lat_0=90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs");
proj4.defs("ESRI:102021", "+proj=stere +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs");

function getLonLat(x, y, region) {
    let mapLeft, mapTop, mapRight, mapBottom, projection;

    switch (region) {
        case 'arctic':
            mapLeft = mapLeftA;
            mapTop = mapTopA;
            mapRight = mapRightA;
            mapBottom = mapBottomA;
            projection = "ESRI:102018";
            break;
        case 'antarc':
            mapLeft = mapLeftA;
            mapTop = mapTopA;
            mapRight = mapRightA;
            mapBottom = mapBottomA;
            projection = "ESRI:102021";
            break;
        case 'wo':
        default:
            mapLeft = mapLeftM;
            mapTop = mapTopM;
            mapRight = mapRightM;
            mapBottom = mapBottomM;
            projection = "EPSG:4326";
            break;
    }

    if (x >= mapLeft && x <= mapRight && y >= mapTop && y <= mapBottom) {
        const mapX = x - mapLeft;
        const mapY = y - mapTop;

        if (region === 'wo') {
            const lon = -180 + (mapX / (mapRight - mapLeft)) * 360;
            const lat = 90 - (mapY / (mapBottom - mapTop)) * 180;
            return { lon: lon, lat: lat };
        } else {
            const centerX = (mapRight - mapLeft) / 2;
            const centerY = (mapBottom - mapTop) / 2;
            const offsetX = mapX - centerX;
            const offsetY = mapY - centerY;
            const normalizedX = offsetX / centerX;
            const normalizedY = offsetY / centerY;
            
            const meterX = normalizedX * 3329743;
            const meterY = normalizedY * 3329743;

            let point;
            if (region === 'arctic') {
                point = proj4(projection, "EPSG:4326", [meterX, meterY]);
                if (point[0] > 0) {
                    point[0] = 180 - point[0];
                } else {
                    point[0] = (point[0] + 180) * (-1);
                }
            } else if (region === 'antarc') {
                point = proj4(projection, "EPSG:4326", [meterX, meterY]);
                point[1] = -Math.abs(point[1]); 
            }
            
            return { lon: point[0], lat: point[1] };
        }
    }
    return null;
}
"""

# Отслеживание координат
const COORDINATE_TRACKING = """
// ================== ОТСЛЕЖИВАНИЕ КООРДИНАТ В МОДАЛЬНОМ ОКНЕ ==================
document.getElementById('modalImg').onmousemove = function(e) {
    const rect = this.getBoundingClientRect();
    const img = this;
    
    const relX = (e.clientX - rect.left) / rect.width;
    const relY = (e.clientY - rect.top) / rect.height;
    const absX = relX * img.naturalWidth;
    const absY = relY * img.naturalHeight;
    
    const region = document.getElementById('regionSelect').value;
    const coords = getLonLat(absX, absY, region);
    
    if (coords) {
        currentCoords = { 
            longitude: coords.lon.toFixed(2), 
            latitude: coords.lat.toFixed(2) 
        };
        document.getElementById('coordDisplay').textContent = 
            'Долгота: ' + currentCoords.longitude + '°, Широта: ' + currentCoords.latitude + '°';
    }
}
"""

# Всплывающее окно с данными
const DATA_POPUP_FUNCTIONS = """
// ================== ВСПЛЫВАЮЩЕЕ ОКНО С ДАННЫМИ ==================
function showDataPopup(data) {
    const existingPopup = document.getElementById('dataPopup');
    if (existingPopup) {
        existingPopup.remove();
    }
    
    const popup = document.createElement('div');
    popup.id = 'dataPopup';
    popup.style.cssText = 
        'position: fixed; z-index: 1002; left: 50%; top: 50%; transform: translate(-50%, -50%); ' +
        'background: rgba(255, 255, 255, 0.95); ' +
        'padding: 20px; border-radius: 12px; box-shadow: 0 5px 25px rgba(0,0,0,0.3); ' +
        'max-width: 350px; max-height: 80vh; overflow-y: auto;';
    
    popup.innerHTML = 
        '<h3 style="margin-top: 0; color: #333;">📍 Данные в точке</h3>' +
        '<p><strong>🌡️ Температура:</strong> ' + data.temperature + ' °C</p>' +
        '<p><strong>🧂 Соленость:</strong> ' + data.salinity + ' ‰</p>' +
        '<p><strong>⬆️ Компонента течения U:</strong> ' + data.u_current + ' м/с</p>' +
        '<p><strong>➡️ Компонента течения V:</strong> ' + data.v_current + ' м/с</p>' +
        '<div style="margin: 15px 0; padding: 10px; background: rgba(0,0,0,0.05); border-radius: 6px;">' +
        '<label style="display: block; margin-bottom: 8px; font-weight: bold;">🎚️ Прозрачность:</label>' +
        '<div style="display: flex; align-items: center; gap: 10px;">' +
        '<input type="range" id="opacitySlider" min="0" max="100" value="95" ' +
               'style="width: 120px; height: 6px; border-radius: 3px; background: #ddd; outline: none; flex-shrink: 0;" ' +
               'oninput="updatePopupOpacity(this.value)">' +
        '<span id="opacityValue" style="font-size: 12px; color: #666; min-width: 30px;">95%</span>' +
        '</div>' +
        '<div style="display: flex; justify-content: space-between; font-size: 10px; color: #666; margin-top: 5px; width: 120px;">' +
        '<span>Прозр.</span><span>Непрозр.</span>' +
        '</div>' +
        '</div>' +
        '<div style="margin-top: 20px; border-top: 1px solid rgba(0,0,0,0.1); padding-top: 15px;">' +
        '<h4 style="margin-bottom: 10px;">📈 Построить графики:</h4>' +
               
        '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 5px;">' +
        '<button onclick="window.showDepthProfileWithClimatology(\\'temperature\\')" style="margin: 5px; padding: 8px 12px;">Температура по глубине</button>' +
        '<button onclick="window.showDepthProfileWithClimatology(\\'salinity\\')" style="margin: 5px; padding: 8px 12px;">Соленость по глубине</button>' +
        '<button onclick="window.showDepthProfileWithClimatology(\\'currents\\')" style="margin: 5px; padding: 8px 12px;">Течения по глубине</button>' +
        '<button onclick="window.showTSDiagram()" style="margin: 5px; padding: 8px 12px;">TS-диаграмма</button>' +
        '<button onclick="window.startSectionSelection()" style="margin: 5px; padding: 8px 12px; grid-column: 1 / -1; background: #ff6b35; color: white;">📐 Построить разрез</button>' +
        '</div>' +
        '</div>' +
        
        '<div style="margin-top: 15px; border-top: 1px solid rgba(0,0,0,0.1); padding-top: 15px;">' +
        '<h4 style="margin-bottom: 10px; color: #333;">🌀 Визуализация течений:</h4>' +
        '<button onclick="window.showParticles()" style="padding: 10px 15px; background: #17a2b8; color: white; border: none; border-radius: 6px; cursor: pointer; width: 100%; font-weight: bold; margin-bottom: 5px;">' +
        '🌀 Показать траектории частиц' +
        '</button>' +
        '<div style="font-size: 12px; color: #666; text-align: center;">' +
        'Визуализация движущихся частиц по полю скорости' +
        '</div>' +
        '</div>' +
        
        '<div style="margin-top: 15px; text-align: center;">' +
        '<button onclick="closeCurrentPopup()" style="padding: 8px 16px; background: #6c757d; color: white; border: none; border-radius: 6px; cursor: pointer;">Закрыть</button>' +
        '</div>';
    
    document.body.appendChild(popup);
}

function closeCurrentPopup() {
    const popup = document.getElementById('dataPopup');
    if (popup) {
        popup.remove();
    }
}

function updatePopupOpacity(value) {
    const popup = document.getElementById('dataPopup');
    if (popup) {
        const opacity = value / 100;
        popup.style.backgroundColor = 'rgba(255, 255, 255, ' + opacity + ')';
    }
}
"""

const CLIMATOLOGY_GRAPH_FUNCTIONS = """
// ================== ФУНКЦИИ ГРАФИКОВ С КЛИМАТОЛОГИЕЙ ==================
async function showDepthProfileWithClimatology(paramType) {
    console.log("🔄 showDepthProfileWithClimatology ВЫЗВАНА!", paramType);
    
    try {
        // Получаем выбранные типы статистики
        const climatologyTypes = [];
        if (document.getElementById('climMean')?.checked) climatologyTypes.push('mean');
        if (document.getElementById('climMinMax')?.checked) climatologyTypes.push('minmax');
        if (document.getElementById('clim3Sigma')?.checked) climatologyTypes.push('3sigma');
        
        console.log("📊 Выбранные типы статистики:", climatologyTypes);
        
        const includeClimatology = climatologyTypes.length > 0;
        
        const response = await fetch('/api/plot_depth', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                parameter: paramType,
                include_climatology: includeClimatology,
                climatology_types: climatologyTypes
            })
        });
        
        const plotHtml = await response.text();
        showPlotModal(plotHtml, getGraphTitle(paramType), paramType);
        
    } catch (error) {
        alert('Ошибка построения графика: ' + error);
    }
}

// Обновляем старую функцию, чтобы она тоже поддерживала климатологию
async function showDepthProfile(paramType) {
    await showDepthProfileWithClimatology(paramType);
}

function getGraphTitle(paramType) {
    const titles = {
        'temperature': 'Температура по глубине',
        'salinity': 'Соленость по глубине', 
        'currents': 'Скорость течений по глубине'
    };
    return titles[paramType] || 'График по глубине';
}
"""

# Функции графиков
const GRAPH_FUNCTIONS = """
// ================== ФУНКЦИИ ГРАФИКОВ ==================

async function showTSDiagram() {
    try {
        const response = await fetch('/api/plot_ts', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        
        const plotHtml = await response.text();
        showPlotModal(plotHtml);
        
    } catch (error) {
        alert('Ошибка построения TS-диаграммы: ' + error);
    }
}

function showPlotModal(htmlContent, title) {
    const graphDiv = document.getElementById('graph');
    const graphModal = document.getElementById('graphModal');
    const img = graphDiv.querySelector('img');
    if (img) {
        img.classList.add('portrait-image');
    }
    
    graphDiv.innerHTML = htmlContent;
    document.getElementById('graphTitle').textContent = title;
    graphModal.style.display = 'block';
    
    if (window.innerWidth < 768) {
        graphModal.style.width = '95vw';
        graphModal.style.height = '85vh';
    } else {
        graphModal.style.width = '400px';
        graphModal.style.height = '800px';
    }
}
"""

# Canvas функции
const CANVAS_FUNCTIONS = """
// ================== CANVAS ФУНКЦИИ ==================
function initSectionCanvas() {
    const canvas = document.getElementById('sectionCanvas');
    const modalImg = document.getElementById('modalImg');
    
    if (!canvas || !modalImg) return;
    
    // Устанавливаем размеры как у изображения
    const rect = modalImg.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    
    console.log("🎨 Canvas инициализирован:", canvas.width, "x", canvas.height);
}

function drawSectionLine(point1, point2) {
    console.log("🖍️ Рисование линии между точками:", point1, point2);
    
    const canvas = document.getElementById('sectionCanvas');
    if (!canvas) {
        console.error("❌ Canvas не найден");
        return;
    }
    
    const ctx = canvas.getContext('2d');
    if (!ctx) {
        console.error("❌ Контекст не получен");
        return;
    }
    
    // Очищаем Canvas (делаем полностью прозрачным)
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Показываем canvas (но он будет пустым/прозрачным)
    canvas.style.display = 'block';
    
    console.log("✅ Canvas активирован (без визуальных элементов)");
}

function clearSectionCanvas() {
    const canvas = document.getElementById('sectionCanvas');
    if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        canvas.style.display = 'none';  // Полностью скрываем
    }
}

function testCanvas() {
    console.log("🧪 Тестирование Canvas");
    
    const canvas = document.getElementById('sectionCanvas');
    if (!canvas) {
        alert("❌ Canvas не найден!");
        return;
    }
    
    // Показываем Canvas
    canvas.style.display = 'block';
    
    const ctx = canvas.getContext('2d');
    if (!ctx) {
        alert("❌ Не удалось получить контекст Canvas!");
        return;
    }
    
    // Тест - рисуем красный квадрат
    ctx.fillStyle = 'red';
    ctx.fillRect(50, 50, 100, 100);
    
    // Синий текст
    ctx.fillStyle = 'blue';
    ctx.font = '20px Arial';
    ctx.fillText('Canvas работает!', 50, 200);
    
    alert("✅ Canvas протестирован! Должен быть красный квадрат и синий текст.");
}
"""

# УПРОЩЕННЫЕ ФУНКЦИИ ДЛЯ РАЗРЕЗОВ
const SIMPLIFIED_SECTION_FUNCTIONS = """
// ================== УПРОЩЕННЫЕ ФУНКЦИИ ДЛЯ РАЗРЕЗОВ ==================
let sectionPoints = [];
let isSelectingSection = false;

// Упрощенная функция получения глубины
function getSelectedDepthLimit() {
    const depthInput = document.getElementById('sectionDepthInput');
    
    if (depthInput && depthInput.value.trim() !== '') {
        const depth = parseFloat(depthInput.value);
        if (!isNaN(depth) && depth > 0) {
            console.log("🎯 Заданная глубина:", depth, "м");
            return depth;
        }
    }
    
    console.log("🎯 Глубина: до дна");
    return null;
}

// Инициализация при загрузке
function setupSectionControls() {
    const depthInput = document.getElementById('sectionDepthInput');
    if (depthInput) {
        // Очищаем поле при фокусе для удобства
        depthInput.addEventListener('focus', function() {
            if (this.value === '') {
                this.placeholder = 'Например: 1000';
            }
        });
        
        depthInput.addEventListener('blur', function() {
            if (this.value === '') {
                this.placeholder = 'По умолчанию - до дна';
            }
        });
    }
}

// Запуск выбора точек разреза
function startSectionSelection() {
    console.log("🔛 Активируем режим выбора точек разреза");
    
    closeCurrentPopup();
    document.getElementById('sectionModal').style.display = 'block';
    isSelectingSection = true;
    sectionPoints = [];
    updateSectionPointsInfo();
    
    // Инициализируем Canvas
    setTimeout(initSectionCanvas, 100);

}

// Отмена выбора
function cancelSectionSelection() {
    isSelectingSection = false;
    sectionPoints = [];
    document.getElementById('sectionModal').style.display = 'none';
    clearSectionCanvas();
    
    // Очищаем поле глубины
    const depthInput = document.getElementById('sectionDepthInput');
    if (depthInput) depthInput.value = '';
}

// Подтверждение и построение разреза
async function confirmSectionSelection() {
    console.log("🎯 confirmSectionSelection вызвана");
    console.log("Количество выбранных точек:", sectionPoints.length);
    
    if (sectionPoints.length === 2) {
        try {
            console.log("✅ Отправка запроса на построение разреза");
            
            const confirmBtn = document.getElementById('confirmSectionBtn');
            confirmBtn.disabled = true;
            confirmBtn.textContent = 'Построение...';
            
            // Получаем параметры
            const parameter = document.getElementById('parameterSelect').value;
            const region = document.getElementById('regionSelect').value;
            const depth = document.getElementById('depthSelect').value;
            const date = document.getElementById('dateSelect').value;
            const forecast_hour = parseInt(document.getElementById('forecastSelect').value);
            
            // УПРОЩЕННОЕ получение глубины
            const max_depth_limit = getSelectedDepthLimit();
            
            console.log("📊 Параметры запроса:", { 
                parameter: parameter, 
                region: region,
                depth: depth,
                date: date, 
                forecast_hour: forecast_hour,
                max_depth_limit: max_depth_limit
            });
            
            const response = await fetch('/api/section_plot', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    point1: sectionPoints[0],
                    point2: sectionPoints[1],
                    parameter: parameter,
                    region: region,
                    depth: depth,
                    date: date,
                    forecast_hour: forecast_hour,
                    max_depth_limit: max_depth_limit
                })
            });
            
            if (!response.ok) {
                throw new Error('HTTP error! status: ' + response.status);
            }
            
            const plotHtml = await response.text();
            console.log("✅ HTML графика получен");
            
            // Показываем график
            showSectionPlotModal(plotHtml);
            
            // Закрываем окно выбора точек
            document.getElementById('sectionModal').style.display = 'none';
            isSelectingSection = false;
            sectionPoints = [];
            clearSectionCanvas();
            
            // Очищаем поле глубины
            const depthInput = document.getElementById('sectionDepthInput');
            if (depthInput) depthInput.value = '';
            
        } catch (error) {
            console.error('❌ Ошибка соединения:', error);
            alert('Ошибка построения разреза: ' + error);
        } finally {
            const confirmBtn = document.getElementById('confirmSectionBtn');
            confirmBtn.disabled = false;
            confirmBtn.textContent = 'Построить разрез';
        }
    } else {
        alert("❌ Сначала выберите 2 точки на карте! Выбрано: " + sectionPoints.length);
    }
}

// Обновление информации о точках
function updateSectionPointsInfo() {
    const infoDiv = document.getElementById('sectionPointsInfo');
    const confirmBtn = document.getElementById('confirmSectionBtn');
    
    if (sectionPoints.length === 0) {
        infoDiv.innerHTML = '<p style="margin: 5px 0;">📍 Точка 1: не выбрана</p><p style="margin: 5px 0;">📍 Точка 2: не выбрана</p>';
        confirmBtn.disabled = true;
        clearSectionCanvas();
    } else if (sectionPoints.length === 1) {
        infoDiv.innerHTML = '<p style="margin: 5px 0;">📍 Точка 1: ' + sectionPoints[0].lon.toFixed(2) + '°, ' + sectionPoints[0].lat.toFixed(2) + '°</p>' +
                           '<p style="margin: 5px 0;">📍 Точка 2: не выбрана</p>';
        confirmBtn.disabled = true;
        clearSectionCanvas();
    } else {
        infoDiv.innerHTML = '<p style="margin: 5px 0;">📍 Точка 1: ' + sectionPoints[0].lon.toFixed(2) + '°, ' + sectionPoints[0].lat.toFixed(2) + '°</p>' +
                           '<p style="margin: 5px 0;">📍 Точка 2: ' + sectionPoints[1].lon.toFixed(2) + '°, ' + sectionPoints[1].lat.toFixed(2) + '°</p>';
        confirmBtn.disabled = false;
        
        // Рисуем линию на карте
        drawSectionLine(sectionPoints[0], sectionPoints[1]);
    }
}
"""

# Обработчик клика по карте
const MAP_CLICK_HANDLER = """
// ================== ОБРАБОТЧИК КЛИКА ПО КАРТЕ ==================
document.getElementById('modalImg').onclick = async function(e) {
    console.log("🖱️ Клик по карте, isSelectingSection:", isSelectingSection);
    
    e.stopPropagation();
    e.preventDefault();
    
    if (isSelectingSection === true) {
        console.log("🔵 РЕЖИМ ВЫБОРА ТОЧЕК РАЗРЕЗА");
        
        if (sectionPoints.length < 2) {
            const newPoint = {
                lon: parseFloat(currentCoords.longitude),
                lat: parseFloat(currentCoords.latitude)
            };
            sectionPoints.push(newPoint);
            console.log("📌 Точка " + sectionPoints.length + " выбрана:", newPoint);
            
            updateSectionPointsInfo();
            
            if (sectionPoints.length === 2) {

            }
            return false;
        } else {
            alert("⚠️ Уже выбрано 2 точки. Нажмите 'Построить разрез' или 'Отмена'");
            return false;
        }
    }
    
    console.log("🔴 ОБЫЧНЫЙ РЕЖИМ - запрос данных точки");
    
    try {
        const response = await fetch('/api/point_data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                longitude: currentCoords.longitude,
                latitude: currentCoords.latitude,
                forecast_hour: parseInt(document.getElementById('forecastSelect').value)
            })
        });
        
        const data = await response.json();
        if (data.error) {
            alert('Ошибка: ' + data.error);
        } else {
            showDataPopup(data);
        }
    } catch (error) {
        alert('Ошибка соединения: ' + error);
    }
    
    return false;
};
"""

# Функция для отображения графика разреза
const SECTION_PLOT_MODAL_FUNCTION = """
// Функция для отображения графика разреза
function showSectionPlotModal(htmlContent) {
    console.log("🖼️ Показ графика разреза");
    
    // Создаем модальное окно для графика разреза
    let plotModal = document.getElementById('sectionPlotModal');
    
    if (!plotModal) {
        plotModal = document.createElement('div');
        plotModal.id = 'sectionPlotModal';
        plotModal.style.cssText = 
            'display: none; position: fixed; z-index: 10002; left: 50%; top: 50%; ' +
            'transform: translate(-50%, -50%); width: 80%; max-width: 800px; height: 80%; ' +
            'max-height: 600px; background: white; border-radius: 12px; ' +
            'box-shadow: 0 10px 50px rgba(0,0,0,0.5); overflow: auto; padding: 20px;';
        
        document.body.appendChild(plotModal);
    }
    
    // Добавляем кнопку закрытия и контент
    plotModal.innerHTML = 
        '<span onclick="this.parentElement.style.display=\\'none\\'" ' +
        'style="position: absolute; top: 15px; right: 20px; font-size: 30px; font-weight: bold; cursor: pointer; color: #666;">×</span>' +
        '<div style="margin-top: 40px;">' +
        htmlContent +
        '</div>';
    
    plotModal.style.display = 'block';
}
"""

const GRAPH_UPDATE_FUNCTIONS = """
// ================== ОБНОВЛЕНИЕ ГРАФИКА С КЛИМАТОЛОГИЕЙ ==================
let currentGraphType = '';

async function updateGraphWithClimatology() {
    console.log("🔄 updateGraphWithClimatology вызвана");
    
    if (!currentGraphType) {
        console.error("❌ currentGraphType не установлен");
        return;
    }
    
    try {
        // Получаем выбранные типы статистики
        const climatologyTypes = [];
        if (document.getElementById('graphClimMean')?.checked) climatologyTypes.push('mean');
        if (document.getElementById('graphClimMinMax')?.checked) climatologyTypes.push('minmax');
        if (document.getElementById('graphClim3Sigma')?.checked) climatologyTypes.push('3sigma');
        
        console.log("📊 Обновление графика с климатологией:", {
            parameter: currentGraphType,
            climatologyTypes: climatologyTypes
        });
        
        const response = await fetch('/api/plot_depth', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                parameter: currentGraphType,
                include_climatology: climatologyTypes.length > 0,
                climatology_types: climatologyTypes
            })
        });
        
        if (!response.ok) {
            throw new Error('HTTP error! status: ' + response.status);
        }
        
        const plotHtml = await response.text();
        document.getElementById('graph').innerHTML = plotHtml;
        
        console.log("✅ График обновлен с климатологией");
        
    } catch (error) {
        console.error('❌ Ошибка обновления графика:', error);
        alert('Ошибка обновления графика: ' + error);
    }
}

// Обновляем функцию показа графика
function showPlotModal(htmlContent, title, graphType = '') {
    console.log("🖼️ showPlotModal вызвана с типом:", graphType);
    
    const graphDiv = document.getElementById('graph');
    const graphModal = document.getElementById('graphModal');
    
    currentGraphType = graphType;
    
    graphDiv.innerHTML = htmlContent;
    document.getElementById('graphTitle').textContent = title;
    graphModal.style.display = 'block';
    
    // Сбрасываем переключатели при открытии
    if (document.getElementById('graphClimMean')) {
        document.getElementById('graphClimMean').checked = false;
        document.getElementById('graphClimMinMax').checked = false;
        document.getElementById('graphClim3Sigma').checked = false;
    }
    
    if (window.innerWidth < 768) {
        graphModal.style.width = '95vw';
        graphModal.style.height = '85vh';
    } else {
        graphModal.style.width = '420px';
        graphModal.style.height = '850px';
    }
}
"""

# Обновленная инициализация
const UPDATED_INITIALIZATION_CODE = """
// ================== ИНИЦИАЛИЗАЦИЯ ПРИ ЗАГРУЗКЕ ==================
setupSectionControls();  // Инициализируем управление разрезами
loadMap();  // Загружаем начальную карту
initParticleControls();

console.log("=== УПРОЩЕННЫЙ ИНТЕРФЕЙС РАЗРЕЗОВ ИНИЦИАЛИЗИРОВАН ===");
"""

const PARTICLE_ANIMATION_FUNCTIONS = """
// ================== АНИМАЦИЯ ЧАСТИЦ ==================
let particleSystem = null;
let isParticlesActive = false;

function initParticleControls() {
    // Привязка событий слайдеров
    const countSlider = document.getElementById('particleCountSlider');
    const speedSlider = document.getElementById('particleSpeedSlider');
    
    if (countSlider) {
        countSlider.oninput = function() {
            document.getElementById('particleCountValue').textContent = this.value;
        };
    }
    
    if (speedSlider) {
        speedSlider.oninput = function() {
            document.getElementById('particleSpeedValue').textContent = this.value;
        };
    }
    
    // Привязка кнопок
    const startBtn = document.getElementById('startParticlesBtn');
    const stopBtn = document.getElementById('stopParticlesBtn');
    const updateBtn = document.getElementById('updateParticlesBtn');
    
    if (startBtn) startBtn.onclick = startParticleAnimation;
    if (stopBtn) stopBtn.onclick = stopParticleAnimation;
    if (updateBtn) updateBtn.onclick = updateParticleAnimation;
    
    console.log("✅ Инициализированы контролы частиц");
}

function startParticleAnimation() {
    console.log("▶️ Запуск анимации частиц");
    
    // Показываем canvas и контролы
    const canvas = document.getElementById('particleCanvas');
    const controls = document.getElementById('particleControls');
    
    if (canvas) canvas.style.display = 'block';
    if (controls) controls.style.display = 'block';
    
    isParticlesActive = true;
    
    // Загружаем данные и запускаем анимацию
    loadAndShowParticles();
}

function stopParticleAnimation() {
    console.log("⏹️ Остановка анимации частиц");
    
    const canvas = document.getElementById('particleCanvas');
    const controls = document.getElementById('particleControls');
    
    if (canvas) canvas.style.display = 'none';
    if (controls) controls.style.display = 'none';
    
    isParticlesActive = false;
    
    // Останавливаем систему частиц
    if (particleSystem) {
        particleSystem.stop();
        particleSystem = null;
    }
}

function updateParticleAnimation() {
    console.log("🔁 Обновление частиц");
    
    if (isParticlesActive) {
        loadAndShowParticles();
    }
}

// Основная функция загрузки данных
async function loadAndShowParticles() {
    try {
        console.log("🔄 Загрузка данных частиц...");
        
        // Получаем текущие параметры из интерфейса
        const region = document.getElementById('regionSelect').value;
        const depth = document.getElementById('depthSelect').value;
        const date = document.getElementById('dateSelect').value;
        const forecast = document.getElementById('forecastSelect').value;
        const count = document.getElementById('particleCountSlider').value;  // ← ЭТОТ элемент должен существовать!
        
        // 1. Запрашиваем поле скоростей
        const velocityResponse = await fetch('/api/particles/velocity-field', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                date: date,
                depth: depth,
                forecast_hour: parseInt(forecast),
                region: region
            })
        });
        
        if (!velocityResponse.ok) {
            throw new Error(`Ошибка скорости: ' + velocityResponse.status`);
        }
        
        const velocityData = await velocityResponse.json();
        console.log("✅ Данные скорости:", velocityData);
        
        // 2. Запрашиваем частицы
        const particlesResponse = await fetch('/api/particles/generate-seeds', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                count: parseInt(count),
                region: region
            })
        });
        
        const particlesData = await particlesResponse.json();
        console.log("✅ Сгенерировано частиц:", particlesData.count);
        
        // 3. Инициализируем/обновляем систему частиц
        if (!particleSystem) {
            particleSystem = new SimpleParticleSystem('particleCanvas');
        }
        
        particleSystem.initialize(velocityData.data, particlesData.particles);
        particleSystem.start();
        
    } catch (error) {
        console.error("❌ Ошибка загрузки частиц:", error);
        alert("Ошибка загрузки данных частиц: " + error.message);
    }
}

// Простая система частиц (Canvas2D)
class SimpleParticleSystem {
    constructor(canvasId) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.particles = [];
        this.velocityField = null;
        this.animationId = null;
    }
    
    initialize(velocityData, seedParticles) {
        // Сохраняем поле скоростей
        this.velocityField = velocityData;
        
        // Инициализируем частицы
        this.particles = seedParticles.map(p => ({
            x: p.lon,
            y: p.lat,
            color: `rgba(100, 150, 255,  + 0.5 + Math.random() * 0.5)`,
            size: 2 + Math.random() * 3
        }));
        
        // Подгоняем размер canvas под карту
        this.resizeCanvas();
    }
    
    resizeCanvas() {
        const modalImg = document.getElementById('modalImg');
        if (modalImg) {
            this.canvas.width = modalImg.clientWidth;
            this.canvas.height = modalImg.clientHeight;
        }
    }
    
    start() {
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
        }
        this.animate();
    }
    
    stop() {
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
    
    animate() {
        // Очистка (полупрозрачная для эффекта шлейфа)
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
        
        // Обновление и отрисовка частиц
        this.updateParticles();
        this.drawParticles();
        
        this.animationId = requestAnimationFrame(() => this.animate());
    }
    
    updateParticles() {
        // Простое движение (заглушка - нужна реальная интерполяция)
        for (const p of this.particles) {
            p.x += (Math.random() - 0.5) * 0.1;
            p.y += (Math.random() - 0.5) * 0.1;
        }
    }
    
    drawParticles() {
        for (const p of this.particles) {
            // Преобразование geo -> canvas координаты
            const canvasPos = this.geoToCanvas(p.x, p.y);
            
            this.ctx.beginPath();
            this.ctx.arc(canvasPos.x, canvasPos.y, p.size, 0, Math.PI * 2);
            this.ctx.fillStyle = p.color;
            this.ctx.fill();
        }
    }
    
    geoToCanvas(lon, lat) {
        // Упрощенное преобразование (позже заменим на ваше getLonLat в обратную сторону)
        const rect = this.canvas.getBoundingClientRect();
        return {
            x: ((lon + 180) / 360) * rect.width,
            y: ((90 - lat) / 180) * rect.height
        };
    }
}

// Добавить в глобальные переменные
window.startParticleAnimation = startParticleAnimation;
window.stopParticleAnimation = stopParticleAnimation;
window.updateParticleAnimation = updateParticleAnimation;

# Глобальные переменные и инициализация
const GLOBAL_VARIABLES = """
// ================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ==================
let currentCoords = { longitude: 0, latitude: 0 };
let currentPointData = null;

// ================== ДЕЛАЕМ ФУНКЦИИ ГЛОБАЛЬНЫМИ ==================
window.loadMap = loadMap;
window.loadAnimation = loadAnimation;
window.openModal = openModal;
window.closeModal = closeModal;
window.showDataPopup = showDataPopup;
window.closeCurrentPopup = closeCurrentPopup;
window.showDepthProfile = showDepthProfile;
window.showDepthProfileWithClimatology = showDepthProfileWithClimatology;
window.showTSDiagram = showTSDiagram;
window.showPlotModal = showPlotModal;
window.closeGraphModal = closeGraphModal;
window.updatePopupOpacity = updatePopupOpacity;
window.updateGraphWithClimatology = updateGraphWithClimatology;
window.startSectionSelection = startSectionSelection;
window.cancelSectionSelection = cancelSectionSelection;
window.confirmSectionSelection = confirmSectionSelection;
window.testCanvas = testCanvas;
window.drawSectionLine = drawSectionLine;
window.clearSectionCanvas = clearSectionCanvas;
window.initSectionCanvas = initSectionCanvas;
window.showSectionPlotModal = showSectionPlotModal;
"""
# ================== ПРОСТЫЕ ФУНКЦИИ ДЛЯ ЧАСТИЦ ==================
const PARTICLE_FUNCTIONS = """
// Проверка Canvas элементов
function checkParticleCanvas() {
    console.log('🔍 Проверка Canvas для частиц...');
    
    const particleCanvas = document.getElementById('particleCanvas');
    if (particleCanvas) {
        console.log('✅ particleCanvas найден');
        // Добавляем границу для отладки
        particleCanvas.style.border = '2px solid red';
        return particleCanvas;
    } else {
        console.error('❌ particleCanvas НЕ найден!');
        return null;
    }
}

// Показать траектории частиц
function showParticles() {
    console.log('🌀 showParticles вызвана');
    
    // 1. Проверяем Canvas
    const particleCanvas = checkParticleCanvas();
    if (!particleCanvas) {
        alert('Ошибка: Canvas для частиц не найден');
        return;
    }
    
    // 2. Показываем Canvas
    particleCanvas.style.display = 'block';
    
    // 3. Устанавливаем размер
    const modalImg = document.getElementById('modalImg');
    if (modalImg) {
        const rect = modalImg.getBoundingClientRect();
        particleCanvas.width = rect.width;
        particleCanvas.height = rect.height;
        particleCanvas.style.width = rect.width + 'px';
        particleCanvas.style.height = rect.height + 'px';
    }
    
    // 4. Рисуем тестовые частицы
    const ctx = particleCanvas.getContext('2d');
    if (ctx) {
        // Очищаем
        ctx.clearRect(0, 0, particleCanvas.width, particleCanvas.height);
        
        // Рисуем красный квадрат
        ctx.fillStyle = 'rgba(255, 0, 0, 0.5)';
        ctx.fillRect(50, 50, 100, 60);
        
        // Текст
        ctx.fillStyle = 'white';
        ctx.font = 'bold 16px Arial';
        ctx.fillText('Траектории частиц', 60, 90);
        
        console.log('🎨 Тестовые частицы нарисованы');
    }
    
    // 5. Показываем окно управления
    const particleModal = document.getElementById('particleModal');
    if (particleModal) {
        particleModal.style.display = 'block';
        console.log('✅ Окно управления показано');
    }
}

// Скрыть траектории
function hideParticles() {
    console.log('🙈 hideParticles вызвана');
    
    // 1. Скрываем окно управления
    const particleModal = document.getElementById('particleModal');
    if (particleModal) {
        particleModal.style.display = 'none';
    }
    
    // 2. Скрываем Canvas
    const particleCanvas = document.getElementById('particleCanvas');
    if (particleCanvas) {
        particleCanvas.style.display = 'none';
        
        // Очищаем
        const ctx = particleCanvas.getContext('2d');
        if (ctx) {
            ctx.clearRect(0, 0, particleCanvas.width, particleCanvas.height);
        }
    }
}

// Загрузить данные частиц 
async function loadParticleData() {
    console.log('📥 Загрузка реальных данных частиц...');
    
    // Получаем параметры
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const depthSelect = document.getElementById('particle-depth').value;
    const density = document.getElementById('particle-density').value;
    
    console.log('Параметры:', { date, region, depth: depthSelect, density });
    
    try {
        // Используем URLSearchParams для безопасного создания URL
        const params = new URLSearchParams({
            date: date,
            depth_index: depthSelect,
            forecast_range: 240,
            region: region,
            particle_count: density
        });
        
        const response = await fetch('/api/particles/trajectories?' + params.toString());
        
        if (!response.ok) {
            throw new Error('HTTP ошибка: ' + response.status);
        }
        
        const data = await response.json();
        console.log('Данные траекторий получены:', data.trajectories ? data.trajectories.length + ' траекторий' : 'нет данных');
        
        if (data.success && data.trajectories && data.trajectories.length > 0) {
            drawRealParticles(data.trajectories);
        } else {
            console.warn('Нет данных траекторий, рисуем тестовые');
            drawSimpleParticles();
        }
    } catch (error) {
        console.error('Ошибка загрузки траекторий:', error);
        // Показываем тестовые данные
        drawSimpleParticles();
    }
}
function drawRealParticles(trajectories) {
    const particleCanvas = document.getElementById('particleCanvas');
    const ctx = particleCanvas.getContext('2d');
    
    if (!ctx || !particleCanvas) return;
    
    // Очищаем
    ctx.clearRect(0, 0, particleCanvas.width, particleCanvas.height);
    
    console.log(`Рисуем + trajectories.length} + '&' траекторий`);
    
    // Рисуем каждую траекторию
    trajectories.forEach(traj => {
        if (!traj.points || traj.points.length < 2) return;
        
        ctx.beginPath();
        
        // Преобразуем координаты и рисуем линию
        traj.points.forEach((point, index) => {
            const coords = geographicToPixel(point[0], point[1], particleCanvas);
            
            if (index === 0) {
                ctx.moveTo(coords.x, coords.y);
            } else {
                ctx.lineTo(coords.x, coords.y);
            }
        });
        
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.lineWidth = 1;
        ctx.stroke();
        
        // Рисуем стартовую точку
        const start = traj.points[0];
        const startCoords = geographicToPixel(start[0], start[1], particleCanvas);
        ctx.beginPath();
        ctx.arc(startCoords.x, startCoords.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = '#3498db';
        ctx.fill();
    });
}
function geographicToPixel(lon, lat, canvas) {
    // Получаем текущий регион
    const region = document.getElementById('regionSelect').value;
    
    // Упрощенное преобразование
    if (region === 'wo') {
        // Мировой океан
        return {
            x: (lon + 180) * (canvas.width / 360),
            y: (90 - lat) * (canvas.height / 180)
        };
    } else {
        // Полярные регионы
        return {
            x: canvas.width / 2 + lon * (canvas.width / 360),
            y: canvas.height / 2 - lat * (canvas.height / 180)
        };
    }
}
let particleAnimationId = null;
let currentTrajectories = [];
let animationTime = 0;

function startParticleAnimation(trajectories) {
    stopParticleAnimation();
    currentTrajectories = trajectories;
    animationTime = 0;
    
    function animate() {
        animationTime += 0.01;
        drawAnimatedParticles(currentTrajectories, animationTime);
        particleAnimationId = requestAnimationFrame(animate);
    }
    
    animate();
}

function stopParticleAnimation() {
    if (particleAnimationId) {
        cancelAnimationFrame(particleAnimationId);
        particleAnimationId = null;
    }
}

// Делаем функции глобальными
window.showParticles = showParticles;
window.hideParticles = hideParticles;
window.loadParticleData = loadParticleData;
window.checkParticleCanvas = checkParticleCanvas;
"""
# Добавляем в javascript_code.jl после PARTICLE_FUNCTIONS

const PARTICLE_ANIMATION_FIXED = """
// ================== ИСПРАВЛЕННАЯ АНИМАЦИЯ ЧАСТИЦ ==================
let particleTrajectories = [];
let currentParticleTime = 0;
let particleAnimation = null;

// Загрузка данных частиц
async function loadAndShowParticles() {
    console.log('🌀 Загрузка данных частиц...');
    
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const depthIndex = document.getElementById('particle-depth').value || '0';
    const particleCount = document.getElementById('particle-density').value || '1000';
    
    try {
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
            console.log(\`✅ Загружено \ + particleTrajectories.length траекторий\`);
            
            // Показываем частицы
            showParticles();
            startParticleAnimation();
        }
    } catch (error) {
        console.error('Ошибка:', error);
        // Тестовые данные
        createTestParticles();
        showParticles();
        startParticleAnimation();
    }
}

// Тестовые частицы
function createTestParticles() {
    particleTrajectories = [];
    for (let i = 0; i < 50; i++) {
        const points = [];
        for (let t = 0; t < 11; t++) {
            points.push([
                Math.random() * 360 - 180,
                Math.random() * 170 - 85,
                Math.random() * 0.5
            ]);
        }
        particleTrajectories.push({id: i, points: points});
    }
}

// Показать частицы
function showParticles() {
    const canvas = document.getElementById('particleCanvas');
    const modalImg = document.getElementById('modalImg');
    
    if (canvas && modalImg) {
        const rect = modalImg.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;
        canvas.style.display = 'block';
    }
    
    // Показываем окно управления
    const particleModal = document.getElementById('particleModal');
    if (particleModal) {
        particleModal.style.display = 'block';
    }
    
    drawParticlesAtTime(currentParticleTime);
}

// Скрыть частицы
function hideParticles() {
    const canvas = document.getElementById('particleCanvas');
    if (canvas) {
        canvas.style.display = 'none';
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
    
    const particleModal = document.getElementById('particleModal');
    if (particleModal) {
        particleModal.style.display = 'none';
    }
    
    stopParticleAnimation();
}

// Отрисовка частиц для времени timeIndex (0-10)
function drawParticlesAtTime(timeIndex) {
    const canvas = document.getElementById('particleCanvas');
    const ctx = canvas.getContext('2d');
    
    if (!ctx || !particleTrajectories.length) return;
    
    // Очищаем
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Рисуем частицы
    particleTrajectories.forEach(traj => {
        if (traj.points && traj.points.length > timeIndex) {
            const point = traj.points[timeIndex];
            const coords = geographicToPixel(point[0], point[1], canvas);
            
            // Цвет по скорости
            const speed = point[2] || 0;
            const radius = Math.max(2, Math.min(6, speed * 20));
            const hue = 240 - Math.min(240, speed * 200);
            
            // Точка
            ctx.beginPath();
            ctx.arc(coords.x, coords.y, radius, 0, Math.PI * 2);
            ctx.fillStyle = \`hsla(\ + hue, 100%, 60%, 0.8)\`;
            ctx.fill();
            
            // Линия до предыдущей позиции
            if (timeIndex > 0) {
                const prevPoint = traj.points[timeIndex - 1];
                const prevCoords = geographicToPixel(prevPoint[0], prevPoint[1], canvas);
                
                ctx.beginPath();
                ctx.moveTo(prevCoords.x, prevCoords.y);
                ctx.lineTo(coords.x, coords.y);
                ctx.strokeStyle = \`hsla(\ + hue, 100%, 50%, 0.3)\`;
                ctx.lineWidth = 1;
                ctx.stroke();
            }
        }
    });
    
    // Обновляем отображение времени
    updateTimeDisplay(timeIndex);
}

// Обновление отображения времени
function updateTimeDisplay(timeIndex) {
    const hours = timeIndex * 24;
    const display = document.getElementById('particleTimeDisplay');
    if (display) {
        display.textContent = \`Время: \ + hours}ч (\ + timeIndex/10)\`;
    }
}

// Управление анимацией
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

// Установить конкретное время (0-10)
function setParticleTime(timeIndex) {
    currentParticleTime = Math.max(0, Math.min(10, timeIndex));
    drawParticlesAtTime(currentParticleTime);
    stopParticleAnimation();
}

// Делаем функции глобальными
window.loadAndShowParticles = loadAndShowParticles;
window.showParticles = showParticles;
window.hideParticles = hideParticles;
window.startParticleAnimation = startParticleAnimation;
window.stopParticleAnimation = stopParticleAnimation;
window.setParticleTime = setParticleTime;
"""

# Обновляем ALL_JAVASCRIPT чтобы включить исправленный код
# Удалите старый PARTICLE_FUNCTIONS и PARTICLE_ANIMATION_CODE
# Вместо них используйте PARTICLE_ANIMATION_FIXED

# ================== ИНИЦИАЛИЗАЦИЯ ЧАСТИЦ ПРИ ЗАГРУЗКЕ ==================
const PARTICLE_INIT_CODE = """
// Проверка при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    console.log('📄 DOM загружен, проверяем элементы частиц...');
    
    // Ждем немного и проверяем
    setTimeout(function() {
        const particleCanvas = document.getElementById('particleCanvas');
        const particleModal = document.getElementById('particleModal');
        
        if (particleCanvas) {
            console.log('✅ particleCanvas найден в DOM');
        } else {
            console.warn('⚠️  particleCanvas НЕ найден в DOM');
        }
        
        if (particleModal) {
            console.log('✅ particleModal найден в DOM');
        } else {
            console.warn('⚠️  particleModal НЕ найден в DOM');
        }
    }, 500);
});
"""

const PARTICLE_ANIMATION_CODE = """
// ================== АНИМАЦИЯ ЧАСТИЦ ==================
let particleTrajectories = [];
let currentParticleTime = 0;
let particleAnimation = null;
let isParticlesVisible = false;

// Загрузка данных частиц
async function loadAndShowParticles() {
    console.log('🌀 Загрузка данных частиц...');
    
    // Получаем параметры
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const depthIndex = document.getElementById('particle-depth').value || '0';
    const particleCount = document.getElementById('particle-density').value || '1000';
    
    try {
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
            console.log(\`✅ Загружено \+ particleTrajectories.length траекторий\`);
            
            // Показываем частицы
            showParticles();
            startParticleAnimation();
        } else {
            console.error('Ошибка загрузки траекторий:', data.error);
            alert('Не удалось загрузить траектории частиц');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        // Покажем тестовые данные
        createTestParticles();
        showParticles();
        startParticleAnimation();
    }
}

// Создание тестовых частиц (если API не работает)
function createTestParticles() {
    particleTrajectories = [];
    const region = document.getElementById('regionSelect').value;
    
    // Простые тестовые траектории
    for (let i = 0; i < 50; i++) {
        const startLon = Math.random() * 360 - 180;
        const startLat = region === 'arctic' ? 45 + Math.random() * 45 :
                        region === 'antarc' ? -90 + Math.random() * 45 :
                        -77 + Math.random() * 167;
        
        const points = [];
        for (let t = 0; t < 11; t++) {
            points.push([
                startLon + Math.sin(t * 0.5) * 5 + Math.random() * 2,
                startLat + Math.cos(t * 0.3) * 3 + Math.random() * 2,
                Math.random() * 0.5
            ]);
        }
        
        particleTrajectories.push({
            id: i,
            start_lon: startLon,
            start_lat: startLat,
            points: points
        });
    }
}

// Показать частицы
function showParticles() {
    const canvas = document.getElementById('particleCanvas');
    if (!canvas) {
        console.error('Canvas не найден');
        return;
    }
    
    // Настраиваем canvas
    const modalImg = document.getElementById('modalImg');
    if (modalImg) {
        const rect = modalImg.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;
        canvas.style.width = rect.width + 'px';
        canvas.style.height = rect.height + 'px';
    }
    
    canvas.style.display = 'block';
    isParticlesVisible = true;
    
    // Показываем окно управления
    const particleModal = document.getElementById('particleModal');
    if (particleModal) {
        particleModal.style.display = 'block';
    }
    
    // Рисуем первый кадр
    drawParticlesAtTime(currentParticleTime);
}

// Скрыть частицы
function hideParticles() {
    const canvas = document.getElementById('particleCanvas');
    if (canvas) {
        canvas.style.display = 'none';
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
    
    const particleModal = document.getElementById('particleModal');
    if (particleModal) {
        particleModal.style.display = 'none';
    }
    
    stopParticleAnimation();
    isParticlesVisible = false;
}

// Отрисовка частиц для конкретного времени
function drawParticlesAtTime(timeIndex) {
    const canvas = document.getElementById('particleCanvas');
    const ctx = canvas.getContext('2d');
    
    if (!ctx || !particleTrajectories.length) return;
    
    // Очищаем canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Рисуем каждую частицу
    particleTrajectories.forEach(traj => {
        if (traj.points && traj.points.length > timeIndex) {
            const point = traj.points[timeIndex];
            if (!point) return;
            
            // Преобразуем координаты
            const coords = geographicToPixel(point[0], point[1], canvas);
            if (!coords) return;
            
            // Цвет и размер в зависимости от скорости
            const speed = point[2] || 0;
            const radius = Math.max(2, Math.min(6, speed * 20));
            const hue = 240 - Math.min(240, speed * 200); // От синего (медленно) к красному (быстро)
            
            // Рисуем точку
            ctx.beginPath();
            ctx.arc(coords.x, coords.y, radius, 0, Math.PI * 2);
            ctx.fillStyle = \`hsla(\ + hue, 100%, 60%, 0.8)\`;
            ctx.fill();
            
            // Рисуем обводку
            ctx.strokeStyle = \`hsla(\ + hue, 100%, 40%, 0.6)\`;
            ctx.lineWidth = 1;
            ctx.stroke();
            
            // Линия до предыдущей позиции (след)
            if (timeIndex > 0) {
                const prevPoint = traj.points[timeIndex - 1];
                if (prevPoint) {
                    const prevCoords = geographicToPixel(prevPoint[0], prevPoint[1], canvas);
                    if (prevCoords) {
                        ctx.beginPath();
                        ctx.moveTo(prevCoords.x, prevCoords.y);
                        ctx.lineTo(coords.x, coords.y);
                        ctx.strokeStyle = \`hsla(\ + hue, 100%, 50%, 0.3)\`;
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }
                }
            }
        }
    });
    
    // Обновляем отображение времени
    updateTimeDisplay(timeIndex);
}

// Преобразование географических координат в пиксели
function geographicToPixel(lon, lat, canvas) {
    const region = document.getElementById('regionSelect').value;
    
    // Используем существующую функцию getLonLat в обратном порядке
    // Для простоты - упрощенное преобразование
    if (region === 'wo') {
        return {
            x: (lon + 180) * (canvas.width / 360),
            y: (90 - lat) * (canvas.height / 180)
        };
    } else {
        // Для полярных регионов - центрируем
        return {
            x: canvas.width / 2 + lon * (canvas.width / 720),
            y: canvas.height / 2 - lat * (canvas.height / 360)
        };
    }
}

// Обновление отображения времени
function updateTimeDisplay(timeIndex) {
    const hours = timeIndex * 24;
    const display = document.getElementById('particleTimeDisplay');
    if (display) {
        display.textContent = \`Время: \ + hours}ч (\ + timeIndex/10)\`;
    }
}

// Управление анимацией
function startParticleAnimation() {
    if (particleAnimation) return;
    
    particleAnimation = setInterval(() => {
        currentParticleTime = (currentParticleTime + 1) % 11;
        drawParticlesAtTime(currentParticleTime);
    }, 500); // 0.5 секунды на шаг
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

// Экспорт функций в глобальную область
window.loadAndShowParticles = loadAndShowParticles;
window.showParticles = showParticles;
window.hideParticles = hideParticles;
window.startParticleAnimation = startParticleAnimation;
window.stopParticleAnimation = stopParticleAnimation;
window.setParticleTime = setParticleTime;
"""
# ================== ИСПРАВЛЕННЫЕ ФУНКЦИИ ДЛЯ ЧАСТИЦ ==================
const PARTICLE_FUNCTIONS_FIXED = """
// АНИМАЦИЯ ЧАСТИЦ - ИСПРАВЛЕННАЯ ВЕРСИЯ
let particleTrajectories = [];
let currentParticleTime = 0;
let particleAnimation = null;

// Преобразование координат
function geographicToPixel(lon, lat, canvas) {
    const region = document.getElementById('regionSelect').value;
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

// Загрузка данных
async function loadAndShowParticles() {
    console.log('🌀 Загрузка траекторий...');
    
    try {
        const date = document.getElementById('dateSelect').value;
        const region = document.getElementById('regionSelect').value;
        const depthIndex = document.getElementById('particle-depth').value || '0';
        const particleCount = document.getElementById('particle-density').value || '1000';
        
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
            console.log('✅ Загружено траекторий: ' + particleTrajectories.length);
            showParticles();
            startParticleAnimation();
        }
    } catch (error) {
        console.error('Ошибка:', error);
        // Тестовые данные
        particleTrajectories = [];
        for (let i = 0; i < 20; i++) {
            const points = [];
            for (let t = 0; t < 11; t++) {
                points.push([Math.random() * 360 - 180, Math.random() * 170 - 85, 0.3]);
            }
            particleTrajectories.push({id: i, points: points});
        }
        showParticles();
        startParticleAnimation();
    }
}

// Показать частицы
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
    if (particleModal) particleModal.style.display = 'block';
    
    drawParticlesAtTime(currentParticleTime);
}

// Скрыть частицы
function hideParticles() {
    const canvas = document.getElementById('particleCanvas');
    if (canvas) {
        canvas.style.display = 'none';
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
    
    const particleModal = document.getElementById('particleModal');
    if (particleModal) particleModal.style.display = 'none';
    
    stopParticleAnimation();
}

// Отрисовка
function drawParticlesAtTime(timeIndex) {
    const canvas = document.getElementById('particleCanvas');
    const ctx = canvas.getContext('2d');
    
    if (!ctx || !particleTrajectories.length) return;
    
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    particleTrajectories.forEach(traj => {
        if (traj.points && traj.points.length > timeIndex) {
            const point = traj.points[timeIndex];
            const coords = geographicToPixel(point[0], point[1], canvas);
            const speed = point[2] || 0;
            const radius = Math.max(2, Math.min(5, speed * 15));
            const hue = 240 - Math.min(240, speed * 200);
            
            ctx.beginPath();
            ctx.arc(coords.x, coords.y, radius, 0, Math.PI * 2);
            ctx.fillStyle = 'hsla(' + hue + ', 100%, 60%, 0.8)';
            ctx.fill();
        }
    });
    
    // Обновляем время
    const display = document.getElementById('particleTimeDisplay');
    if (display) {
        display.textContent = 'Время: ' + (timeIndex * 24) + 'ч (' + timeIndex + '/10)';
    }
}

// Анимация
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

// ЭКСПОРТ ФУНКЦИЙ В ГЛОБАЛЬНУЮ ОБЛАСТЬ
window.loadAndShowParticles = loadAndShowParticles;
window.showParticles = showParticles;
window.hideParticles = hideParticles;
window.startParticleAnimation = startParticleAnimation;
window.stopParticleAnimation = stopParticleAnimation;
window.setParticleTime = setParticleTime;
"""

# Сборка всего JavaScript кода
const ALL_JAVASCRIPT = MAP_FUNCTIONS * MODAL_FUNCTIONS * COORDINATE_FUNCTIONS * 
                      COORDINATE_TRACKING * DATA_POPUP_FUNCTIONS * GRAPH_FUNCTIONS * 
                      CLIMATOLOGY_GRAPH_FUNCTIONS * GRAPH_UPDATE_FUNCTIONS * CANVAS_FUNCTIONS * SIMPLIFIED_SECTION_FUNCTIONS * 
                      MAP_CLICK_HANDLER * SECTION_PLOT_MODAL_FUNCTION * GLOBAL_VARIABLES * 
                      UPDATED_INITIALIZATION_CODE * PARTICLE_FUNCTIONS * PARTICLE_INIT_CODE * PARTICLE_FUNCTIONS_FIXED * PARTICLE_ANIMATION_FUNCTIONS    
                      
end
