# Настройка раздела «Видео сабактар»

## Сначала можно посмотреть дизайн — без настройки Premium

Из корня Flutter-проекта запустите:

```bash
flutter pub get
flutter run --dart-define=DESIGN_PREVIEW=true
```

Для просмотра на ноутбуке в Chrome:

```bash
flutter run -d chrome --dart-define=DESIGN_PREVIEW=true
```

Предпросмотр открывает «Видео» и позволяет переключать все три вкладки,
уровни A1–C1, четыре сферы, связанные разделы и страницы уроков. С главной
доступны меню субтестов и инструкции. Реальные тесты не запускаются.
В настройках можно проверить язык, аватар и имя демо-профиля.

Содержимое уроков и изображения — демонстрационные. Воспроизведение реальных
видео, Firebase, RevenueCat, оплата и изменения аккаунта отключены. Баннер
«ДЕМО» всегда виден. Обычная сборка не меняет доступ к приватным файлам.
Флаг действует только в debug: в profile/release он всегда игнорируется.

Для отдельного проверочного APK (нужен Android SDK):

```bash
flutter build apk --debug --dart-define=DESIGN_PREVIEW=true
```

Полученный `build/app/outputs/flutter-apk/app-debug.apk` — только для локальной
проверки. Не публикуйте его в магазине и не устанавливайте поверх рабочего
приложения без резервной копии. Для обычного запуска уберите флаг.

Проверки интерфейса:

```bash
flutter analyze
flutter test
flutter test --dart-define=DESIGN_PREVIEW=true
```

Предпросмотр не требует развёртывания Cloud Functions. После утверждения
дизайна переходите к настройке ниже.

## Защищённый доступ в рабочем приложении

Бакет MinIO `videos` остаётся приватным. Firestore хранит только метаданные и
ключи объектов. Firebase Cloud Functions проверяют Firebase Authentication и
Premium в RevenueCat, после чего выдают временные подписанные ссылки.

Секретный ключ MinIO нельзя помещать во Flutter, Firestore, Git или `.env`.

## 1. Структура MinIO

```text
videos/
  A1/
    personal/
      greeting/
        001.mp4
        001.jpg
```

`videos` — название бакета. В Firestore указываются ключи без названия бакета:

```text
A1/personal/greeting/001.mp4
A1/personal/greeting/001.jpg
```

Ключ MinIO, используемый Firebase, должен иметь только следующие разрешения:

- `s3:GetBucketLocation` для `arn:aws:s3:::videos`;
- `s3:GetObject` для `arn:aws:s3:::videos/*`.

Обычное открытие адреса объекта должно возвращать `403 AccessDenied`.

## 2. Документ Firestore

Для каждого урока создайте документ в коллекции `videos`:

```text
level: "A1"
sphere: "personal"
section: "greeting"
title: "Саламдашуу"
titleRu: "Приветствие"
description: "..."
descriptionRu: "..."
videoObjectKey: "A1/personal/greeting/001.mp4"
thumbnailObjectKey: "A1/personal/greeting/001.jpg"
duration: 180
order: 1
isActive: true
```

Поля `videoUrl` и `thumbnailUrl` приложением не используются. Истекающие
подписанные ссылки нельзя сохранять в Firestore.

Дополнительно поддерживаются:

```text
titleKy
descriptionKy
sectionTitle
sectionTitleKy
sectionTitleRu
```

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

Разделы личной сферы:

```text
greeting
farewell
address
congratulations
wishes
introduction
```

Разделы остальных сфер появляются во втором ComboBox из активных документов
Firestore. Для корректных названий укажите `sectionTitleKy` и
`sectionTitleRu`.

## 4. Секрет Firebase

Из корня проекта выполните:

```bash
firebase functions:secrets:set VIDEO_ACCESS_CONFIG
```

Введите одну JSON-строку с реальными значениями вместо примеров:

```json
{
  "minio": {
    "endPoint": "media.kyrgyztest.kg",
    "port": 443,
    "useSSL": true,
    "region": "us-east-1",
    "bucket": "videos",
    "accessKey": "MINIO_READ_ONLY_ACCESS_KEY",
    "secretKey": "MINIO_READ_ONLY_SECRET_KEY"
  },
  "revenueCat": {
    "apiKey": "REVENUECAT_V1_SECRET_API_KEY",
    "entitlementId": "KyrgyzTest Pro"
  }
}
```

RevenueCat API key должен быть секретным серверным ключом V1, а не публичным
SDK-ключом из мобильного приложения. `entitlementId` должен в точности
совпадать с идентификатором entitlement в RevenueCat.

После сохранения секрета разверните функции:

```bash
firebase deploy --only functions:getVideoLessons,functions:getVideoPlaybackUrl
```

## 5. Проверка Premium

Firebase UID используется как RevenueCat App User ID. Приложение уже вызывает
`Purchases.logIn(user.uid)`, поэтому эту синхронизацию необходимо сохранить.

Доступ определяется активным entitlement RevenueCat. Коллекция
`premium_access` и клиентский `users.isPremium` не предоставляют платный доступ.
Восстановление покупок доступно в «Настройки → Подписка Premium».

Для проверок используйте Test Store в debug или Google Play License testing.
Добавьте только тестовые Firebase UID в `revenueCat.sandboxUserIds` внутри
`VIDEO_ACCESS_CONFIG`. Для остальных пользователей sandbox-покупки отклоняются.
После тестов удалите лишние UID. Сам список не выдаёт Premium без покупки.

Полный порядок подключения магазина и сборки:
[Android release setup](android_release_setup.md).

## 6. Ожидаемое поведение

- Прямая ссылка MinIO возвращает `403 AccessDenied`.
- `getVideoLessons` возвращает активные уроки и подписанные ссылки превью.
- `getVideoPlaybackUrl` выдаёт ссылку на видео только Premium-пользователю.
- Ссылка автоматически перестаёт работать через 15 минут.
- MinIO поддерживает `GET`, `HEAD` и byte-range запросы для воспроизведения и
  перемотки MP4.
