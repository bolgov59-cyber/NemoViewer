# /home/igor/web/NemoViewer/src/models/particle_cache.jl
"""
Модуль для работы с кэшем траекторий частиц.
"""
module ParticleCache

using Dates, JSON, LibPQ

# Используем существующее подключение из DatabaseFunctions
include("../utils/database_functions.jl")
using ..DatabaseFunctions: get_connection

export get_cached_trajectories, save_trajectories_to_cache

# Кэшировать на 7 дней (можно увеличить при необходимости)
const CACHE_TTL_DAYS = 7

"""
Проверить наличие траекторий в кэше.
"""
function get_cached_trajectories(date, depth_index, forecast_range, region, particle_count, grid_resolution)
    conn = get_connection()
    try
        query = """
        SELECT trajectories 
        FROM particle_cache 
        WHERE date = \$1 
          AND depth_index = \$2 
          AND forecast_range = \$3 
          AND region = \$4 
          AND particle_count = \$5 
          AND grid_resolution = \$6
          AND created_at > NOW() - INTERVAL '\$7 days'
        LIMIT 1
        """
        
        result = execute(conn, query, [
            date, depth_index, forecast_range, 
            region, particle_count, grid_resolution,
            CACHE_TTL_DAYS
        ])
        
        if !isempty(result)
            println("✅ Кэш найден")
            return JSON.parse(first(result).trajectories)
        end
        return nothing
    finally
        close(conn)
    end
end

"""
Сохранить траектории в кэш.
"""
function save_trajectories_to_cache(date, depth_index, forecast_range, region, particle_count, grid_resolution, trajectories)
    conn = get_connection()
    try
        trajectories_json = JSON.json(trajectories)
        
        query = """
        INSERT INTO particle_cache 
            (date, depth_index, forecast_range, region, particle_count, grid_resolution, trajectories)
        VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7::jsonb)
        ON CONFLICT (date, depth_index, forecast_range, region, particle_count, grid_resolution) 
        DO UPDATE SET 
            trajectories = EXCLUDED.trajectories,
            created_at = NOW()
        """
        
        execute(conn, query, [
            date, depth_index, forecast_range, 
            region, particle_count, grid_resolution,
            trajectories_json
        ])
        
        println("✅ Траектории сохранены в кэш")
        return true
    catch e
        println("⚠️  Ошибка сохранения в кэш: $e")
        return false
    finally
        close(conn)
    end
end

end  # module ParticleCache
