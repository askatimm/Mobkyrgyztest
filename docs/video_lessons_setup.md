# Настройка раздела «Видео сабактар»

Приложение читает активные уроки из коллекции Firestore `videos`, а сами
видеофайлы и превью загружает по HTTPS с `media.kyrgyztest.kg`.

## 1. Структура MinIO

В бакете `videos` используйте следующую структуру объектов:

```text
{level}/{sphere}/{section}/{number}.mp4
{level}/{sphere}/{section}/{number}.jpg
```

Пример:

```text
A1/personal/greeting/001.mp4
A1/personal/greeting/001.jpg
```

Итоговые публичные адреса:

```text
https://media.kyrgyztest.kg/videos/A1/personal/greeting/001.mp4
https://media.kyrgyztest.kg/videos/A1/personal/greeting/001.jpg
```

Для мобильного приложения нужны постоянные HTTPS-ссылки. Истекающие MinIO
presigned URL нельзя сохранять в Firestore как постоянные адреса. Если бакет
закрытый, выдачу временных ссылок следует делать через отдельный защищённый
backend.

## 2. Метаданные Firestore

Для каждого урока создайте отдельный документ в коллекции `videos`:

```json
{
  "level": "A1",
  "sphere": "personal",
  "section": "greeting",
  "title": "Саламдашуу жана таанышуу",
  "description": "Саламдашуу, таанышуу жана жөнөкөй суроолор",
  "videoUrl": "https://media.kyrgyztest.kg/videos/A1/personal/greeting/001.mp4",
  "thumbnailUrl": "https://media.kyrgyztest.kg/videos/A1/personal/greeting/001.jpg",
  "duration": 192,
  "order": 1,
  "isActive": true
}
```

Обязательные поля:

| Поле | Тип | Пример |
|---|---|---|
| `level` | string | `A1` |
| `sphere` | string | `personal` |
| `section` | string | `greeting` |
| `title` | string | `Саламдашуу жана таанышуу` |
| `description` | string | описание урока |
| `videoUrl` | string | постоянный HTTPS URL видео |
| `thumbnailUrl` | string | постоянный HTTPS URL изображения |
| `duration` | number | длительность в секундах |
| `order` | number | порядок внутри раздела |
| `isActive` | boolean | показывать ли урок |

Дополнительно поддерживаются локализованные поля:

```json
{
  "titleKy": "Саламдашуу жана таанышуу",
  "titleRu": "Приветствие и знакомство",
  "descriptionKy": "Саламдашуу, таанышуу жана жөнөкөй суроолор",
  "descriptionRu": "Приветствие, знакомство и простые вопросы",
  "sectionTitleKy": "Саламдашуу",
  "sectionTitleRu": "Приветствие"
}
```

Если локализованные поля отсутствуют, приложение использует `title`,
`description` и встроенное название известного раздела.

## 3. Допустимые коды

Уровни:

```text
A1, A2, B1, B2, C1
```

Сферы:

```text
personal
professional
social_cultural
educational
```

Встроенные разделы личной сферы:

```text
greeting
farewell
address
congratulations
wishes
introduction
```

Разделы остальных сфер не зашиты в приложение: они автоматически появляются
во втором ComboBox, когда в Firestore добавлен хотя бы один активный урок с
соответствующим `section`. Для корректных кыргызских и русских названий укажите
`sectionTitleKy` и `sectionTitleRu`.

## 4. Доступ и CORS

- Разрешите приложению читать активные документы коллекции `videos`.
- Запись в `videos` должна быть доступна только администраторам.
- На `media.kyrgyztest.kg` включите `GET`, `HEAD` и byte-range запросы. Они
  нужны для перемотки и потокового воспроизведения MP4.
- Для Flutter Web добавьте CORS origin вашего веб-приложения. Android и iOS
  CORS не используют.

После добавления документа с `isActive: true` урок появится в приложении без
выпуска новой версии.
