using Genie, Genie.Router, Genie.Renderer
using Dates

# Импортируем функции из нашего модуля
include("src/config/database.jl")
include("src/utils/database_functions.jl")

using .DatabaseFunctions: get_latest_date  

# Инициализируем GenieSession (ОДИН РАЗ!)
try
    using GenieSession
    using GenieSessionFileSession
    GenieSession.__init__()
catch e
    @warn "GenieSession не загружен: $e"
    println("⚠️ Сессии отключены. Данные будут общими для всех пользователей.")
end

# Конфигурация приложения
const APP_CONFIG = ( max_distance = 0.25,)


# Загружаем последнюю дату при старте
function load_latest_date()
    try
        return DatabaseFunctions.get_latest_date()
    catch e
        @warn "Не удалось загрузить последнюю дату из БД: $e"
        return Date(2024, 1, 15)
    end
end

const LATEST_DATE = load_latest_date()

# Регистрируем маршруты
include("src/routes/main_routes.jl")  # ← ЭТО загружает функцию
main_routes()                         # ← ЭТО вызывает функцию и регистрирует маршруты
include("src/routes/api_routes.jl")

# Подключаем модуль частиц
include("src/models/particle_tracer.jl")
include("src/routes/particle_routes.jl")
 
route("/api/test", method = GET) do
    return "✅ Сервер работает! API доступен."
end

println("✅ Маршруты зарегистрированы")
# Запускаем сервер 
Genie.config.run_as_server = true
Genie.Server.up(8000, "0.0.0.0")
