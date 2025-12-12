# /home/igor/web/NemoViewer/src/models/particle_cache_simple.jl

using Dates, JSON, LibPQ

# Кэшировать на 7 дней
const CACHE_TTL_DAYS = 7

"""
Функция подключения к БД.
"""
function get_particle_connection()
    # Используем настройки из config/database.jl
    include(joinpath(@__DIR__, "..", "config", "database.jl"))
    
    conn_str = "dbname=$(DB_CONFIG.dbname) user=$(DB_CONFIG.user) password=$(DB_CONFIG.password) host=$(DB_CONFIG.host) port=$(DB_CONFIG.port)"
    try
        conn = LibPQ.Connection(conn_str)
        return conn
    catch e
        println("❌ Ошибка подключения к БД: ", e)
        rethrow(e)
    end
end

"""
Проверить наличие траекторий в кэше.
"""
function get_cached_trajectories(date, depth_index, forecast_range, region, particle_count, grid_resolution)
    conn = get_particle_connection()
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
    conn = get_particle_connection()
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
