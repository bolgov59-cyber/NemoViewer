# /home/igor/web/NemoViewer/src/models/particle_tracer.jl
module ParticleTracer

using Dates, JSON, Random

export calculate_particle_trajectories

"""
Генерация реалистичных тестовых траекторий.
Позже заменим на реальные данные из БД.
"""
function calculate_particle_trajectories(
    date::Date, depth_index::Int, forecast_range::Int, region::String;
    particle_count::Int = 1000
)
    println("🎯 Генерация траекторий: $date, горизонт $depth_index, регион $region, частиц: $particle_count")
    
    # Ограничим для тестирования
    actual_count = min(particle_count, 500)
    
    trajectories = []
    time_steps = min(forecast_range ÷ 24 + 1, 11)  # Макс 11 временных шагов
    
    # Границы регионов
    bounds = Dict(
        "wo" => (lon_min=-180.0, lon_max=180.0, lat_min=-77.0, lat_max=90.0),
        "arctic" => (lon_min=-180.0, lon_max=180.0, lat_min=45.0, lat_max=90.0),
        "antarc" => (lon_min=-180.0, lon_max=180.0, lat_min=-90.0, lat_max=-45.0)
    )
    
    bounds = get(bounds, region, bounds["wo"])
    
    for i in 1:actual_count
        # Случайная стартовая позиция в регионе
        start_lon = rand() * (bounds.lon_max - bounds.lon_min) + bounds.lon_min
        start_lat = rand() * (bounds.lat_max - bounds.lat_min) + bounds.lat_min
        
        points = []
        current_lon, current_lat = start_lon, start_lat
        
        # Создаем "реалистичное" движение с дрейфом
        for t in 0:time_steps-1
            # Простой дрейф: добавляем немного случайности + тренд
            drift_lon = 0.1 * sin(t * 0.5) + randn() * 0.05
            drift_lat = 0.1 * cos(t * 0.3) + randn() * 0.05
            
            # Обновляем позицию
            current_lon += drift_lon
            current_lat += drift_lat
            
            # Ограничиваем в пределах региона
            current_lon = clamp(current_lon, bounds.lon_min, bounds.lon_max)
            current_lat = clamp(current_lat, bounds.lat_min, bounds.lat_max)
            
            # Скорость для визуализации
            speed = sqrt(drift_lon^2 + drift_lat^2) * 50  # Усилим для наглядности
            
            push!(points, [
                round(current_lon, digits=4),
                round(current_lat, digits=4),
                round(speed, digits=4)
            ])
        end
        
        push!(trajectories, Dict(
            "id" => i,
            "start_lon" => round(start_lon, digits=4),
            "start_lat" => round(start_lat, digits=4),
            "points" => points
        ))
    end
    
    println("✅ Сгенерировано $(length(trajectories)) траекторий")
    return trajectories
end

end  # module ParticleTracer
