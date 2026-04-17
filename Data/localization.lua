local CHESS_LOCALIZATION = {}

CHESS_LOCALIZATION.eng = {
	create = 'Create',
	join = 'Join',
	settings = 'Settings',
	local_game = 'Local game',
	quit = 'Quit',
	nickname = 'Nickname',
	ready = 'Ready',
	not_ready = 'Unready',
	interface = 'Interface',
	connect = 'Connect',
	output_device = 'Output device',
	black = 'Black',
	white = 'White',
	volume = 'Volume',
	ip_adress = 'IP Adress',
	sound = 'Sound',
	about = 'About',
	language = "Language",
	color_scheme = 'Color scheme',
	-- white_to_ = 'Color scheme',
	restart = 'Restart',
	resign = 'Resign',
	lobby = 'Lobby',
	network = 'Network',
	check_for_update = 'Check for update',
	no_updates = 'No updates',
	succes = 'Succes',
	updating = 'Updating',
	computer_id = 'Computer ID',
	connection_type = 'Connection type',
	about_textBlock1 = [[Goal:
	Win by checkmating the opponent’s king. A king is in check if it is attacked by an enemy piece. If the king cannot escape the attack, the game ends immediately.
	]],

	about_textBlock2 = [[
	How pieces move:

	Pawn — moves forward 1 square; on its first move it may move 2 squares if both squares are empty. Pawns capture one square diagonally forward.
	Rook — moves any number of squares horizontally or vertically.
	Knight — moves in an “L” shape: 2 squares in one direction and 1 square perpendicular. Knights can jump over pieces.]],

	about_textBlock3 =
	[[Bishop — moves any number of squares diagonally.
	Queen — moves like a rook or bishop, any number of squares.
	King — moves 1 square in any direction.
	]],

	about_textBlock4 = [[
	Special rules:

	Castling — a special move involving the king and one rook. The king moves 2 squares toward the rook, and the rook jumps to the square next to the king. Castling is allowed only if neither piece has moved, the squares between them are empty, the king is not in check, and the king does not move through or onto an attacked square.
	En passant — if an enemy pawn moves 2 squares forward and lands next to your pawn, your pawn may capture it as if it had moved only 1 square, but only on the very next move.
	Promotion — if a pawn reaches the last rank, it is promoted to another piece, usually a queen.]],

	about_textBlock5 = [[
	End of the game:

	Checkmate — the king is in check and has no legal move to escape. This means the player loses.
	Stalemate — the player has no legal moves, but the king is not in check. This is a draw.
	A game can also end in a draw by repetition, the 50-move rule, or insufficient material.]]
}

CHESS_LOCALIZATION.ukr = {
	create = 'Створити',
	join = 'Увійти',
	settings = 'Налаштування',
	local_game = 'Локальна гра',
	quit = 'Вихід',
	nickname = "Ім'я",
	ready = 'Готов',
	not_ready = 'Не готовий',
	sound = 'Звук',
	interface = 'Інтерфейс',
	black = 'Чорні',
	about = 'Довідка',
	white = 'Білі',
	ip_adress = 'IP Адреса',
	volume = 'Гучність',
	output_device = 'Пристрій виведення',
	connect = "Під'єднатись",
	language = "Мова",
	color_scheme = 'Палітра кольорів',
	restart = 'Нова гра',
	resign = 'Здатися',
	lobby = 'Лоббі',
	network = 'Мережа',
	check_for_update = 'Перевірити оновлення',
	no_updates = 'Оновлень немає',
	succes = 'Успішно',
	updating = 'Оновлення',
	computer_id = "ID Ком'ютера",
	connection_type = "Тип з'єднання",
	about_textBlock1 = [[Мета гри:
	Перемогти, поставивши королю суперника мат. Король перебуває під шахом, якщо його атакує фігура суперника. Якщо король не може уникнути атаки, партія одразу закінчується.]],

	about_textBlock2 =
	[[
	Як ходять фігури:

	Пішак — ходить вперед на 1 клітинку; з початкової позиції може піти на 2 клітинки, якщо обидві клітинки порожні. Б’є пішак по діагоналі вперед на 1 клітинку.
	Тура — ходить на будь-яку кількість клітинок по горизонталі або вертикалі.
	Кінь — ходить буквою “Г”: 2 клітинки в один бік і 1 — перпендикулярно. Кінь може перестрибувати через інші фігури.]],

	about_textBlock3 =
	[[Слон — ходить на будь-яку кількість клітинок по діагоналі.
	Ферзь — поєднує хід тури і слона, ходить на будь-яку кількість клітинок.
	Король — ходить на 1 клітинку в будь-якому напрямку.
	]],

	about_textBlock4 = [[
	Особливі правила:

	Рокіровка — спеціальний хід короля і тури. Король зміщується на 2 клітинки в бік тури, а тура стає на клітинку поруч із королем. Рокіровка можлива лише якщо ні король, ні тура ще не ходили, між ними немає фігур, король не перебуває під шахом і не проходить через атаковані клітинки.
	Взяття на проході — якщо ворожий пішак зробив початковий хід на 2 клітинки і став поруч із твоїм пішаком, твій пішак може взяти його так, ніби той пішак пішов лише на 1 клітинку. Це можливо тільки одразу на наступному ході.
	Перетворення пішака — якщо пішак доходить до останньої горизонталі, його можна перетворити на іншу фігуру, зазвичай на ферзя.
	]],

	about_textBlock5 = [[
	Кінець партії:

	Мат — король під шахом і не має жодного допустимого ходу для порятунку. Це поразка.
	Пат — у гравця немає жодного допустимого ходу, але король не під шахом. Це нічия.
	Також нічия можлива через триразове повторення позиції, правило 50 ходів або недостатню кількість матеріалу.]]
}

CHESS_LOCALIZATION.rus = {
	create = 'Создать',
	join = 'Войти',
	settings = 'Настройки',
	local_game = 'Локальная игра',
	quit = 'Выход',
	ip_adress = 'IP Адресс',
	black = 'Чёрные',
	white = 'Белые',
	nickname = 'Имя',
	sound = 'Звук',
	interface = 'Интерфейс',
	ready = 'Готов',
	not_ready = 'Не готов',
	about = 'Справка',
	volume = 'Громкость',
	output_device = 'Устройство вывода',
	connect = 'Подключиться',
	color_scheme = 'Цветовая палитра',
	language = "Язык",
	restart = 'Рестарт',
	resign = 'Сдаться',
	lobby = 'Лобби',
	network = 'Сеть',
	check_for_update = 'Проверить обновления',
	no_updates = 'Обновлений нет',
	succes = 'Успешно',
	updating = 'Обновление',
	computer_id = 'ID Компьютера',
	connection_type = 'Тип соединения',
	about_textBlock1 = [[Цель игры:
	Победить, поставив королю соперника мат. Король находится под шахом, если он атакован фигурой противника. Если король не может уйти от атаки, партия сразу заканчивается.]],

	about_textBlock2 =
	[[
	Как ходят фигуры:

	Пешка — ходит вперёд на 1 клетку; с начальной позиции может пойти на 2 клетки, если обе клетки свободны. Бьёт пешка по диагонали вперёд на 1 клетку.
	Ладья — ходит на любое количество клеток по горизонтали или вертикали.
	Конь — ходит буквой “Г”: 2 клетки в одну сторону и 1 — перпендикулярно. Конь может перепрыгивать через другие фигуры.]],

	about_textBlock3 =
	[[Слон — ходит на любое количество клеток по диагонали.
	Ферзь — сочетает ход ладьи и слона, ходит на любое количество клеток.
	Король — ходит на 1 клетку в любом направлении.]],

	about_textBlock4 = [[
	Особые правила:

	Рокировка — специальный ход короля и ладьи. Король смещается на 2 клетки в сторону ладьи, а ладья ставится на клетку рядом с королём. Рокировка возможна только если ни король, ни ладья ещё не ходили, между ними нет фигур, король не находится под шахом и не проходит через атакованные клетки.
	Взятие на проходе — если вражеская пешка сделала начальный ход на 2 клетки и оказалась рядом с твоей пешкой, твоя пешка может взять её так, как будто та пошла только на 1 клетку. Это возможно только сразу на следующем ходу.
	Преобразование пешки — если пешка доходит до последней горизонтали, она превращается в другую фигуру, обычно в ферзя.
	]],

	about_textBlock5 = [[
	Конец партии:

	Мат — король под шахом и не имеет ни одного законного хода для спасения. Это поражение.
	Пат — у игрока нет ни одного законного хода, но король не под шахом. Это ничья.
	Также ничья возможна из-за троекратного повторения позиции, правила 50 ходов или недостатка материала.]]
}


return CHESS_LOCALIZATION