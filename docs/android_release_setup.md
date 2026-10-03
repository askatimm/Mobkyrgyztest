# KyrgyzTest: RevenueCat и первый релиз в Google Play

Этот документ описывает подготовку, а не подтверждает готовность к публикации.
Первая площадка — Google Play. Аккаунт разработчика пока не создан, проект
RevenueCat уже есть. IIS/MinIO для этой работы перенастраивать не нужно.

## 1. Создать аккаунт Google Play

Откройте [Play Console](https://play.google.com/console/signup).
Выберите тип аккаунта по фактическому владельцу приложения: Personal для
физического лица, Organization для организации. Владелец сам принимает
соглашение, оплачивает регистрацию и проходит проверку личности/организации.
Уточните право использовать название «Кыргызтест», материалы и контактные
данные организации перед публикацией от её имени.

На 3 октября 2026 года Google указывает разовый сбор $25. Для новых личных
аккаунтов перед production нужен закрытый тест: минимум 12 тестировщиков,
непрерывно подключённых минимум 14 дней, затем заявка на доступ к production.
Условия и доступность платежей проверяйте в своей Play Console.

Создайте карточку приложения. Package name первой загруженной сборки:
**`kg.kyrgyztest.app`**. Уже настроенные Firebase/Google Sign-In используют его.
Не меняйте идентификатор ради названия в магазине.

## 2. Подписка в Google Play

Сначала настройте платёжный профиль для продаж. Страну, юридические и банковские
данные заполняет владелец аккаунта. Убедитесь, что аккаунт может продавать
подписки в выбранной стране.

В карточке приложения создайте автоматически продлеваемую подписку и её base
plan. Идентификатор, период и цена выбираются владельцем. Не обещайте цену до
настройки магазина: приложение показывает цену через RevenueCat paywall.
Для первого запуска достаточно одного тарифа. Активируйте base plan и страны
продаж; ознакомьтесь с grace period и account hold.

## 3. Подключить существующий проект RevenueCat

1. В проекте добавьте/проверьте приложение Google Play с package name
   `kg.kyrgyztest.app`.
2. Настройте Google Play service account по официальной инструкции RevenueCat.
   Загрузите его JSON только в закрытый раздел RevenueCat. Это секретный
   серверный файл, его нельзя коммитить или передавать в чат.
3. Импортируйте фактические store product/base plan identifiers.
4. В Entitlements проверьте **identifier**, а не display name:
   **`KyrgyzTest Pro`**. Если уже используется другой identifier, задайте его
   одинаково в мобильной конфигурации и секрете Firebase.
5. Прикрепите store products к entitlement. Создайте Offering с подходящим
   package и назначьте Current. Для отдельного Offering задайте
   `REVENUECAT_OFFERING_ID`, иначе приложение использует Current.
6. Создайте и опубликуйте RevenueCat paywall для этого Offering. Укажите
   реальные условия, стоимость из store product, период, автопродление,
   отмену, privacy/terms URLs и кнопку восстановления.
7. Проверьте restore/transfer behavior проекта. Для приложения с обязательным
   Firebase-входом рассмотрите **Keep with original App User ID**, чтобы покупка
   не переходила другому Firebase-аккаунту с тем же store account. Если покупка
   принадлежит другому аккаунту, пользователь должен войти в исходный аккаунт.
   Не меняйте эту настройку вслепую, если в проекте уже есть покупатели.

Ключ Flutter — **Google Play public SDK key `goog_…`**, не Secret API key.
Публичный SDK-ключ уже был в коде; перед релизом сверьте его с нужным проектом.
Код теперь синхронизирует Firebase UID при старте, регистрации, входе и смене
аккаунта, а восстановление выполняется только после нажатия кнопки.

### Проверка дизайна до создания Google Play

Без оплаты: `flutter run --dart-define=DESIGN_PREVIEW=true`.

Для проверки механики покупок можно использовать RevenueCat Test Store в
**debug**-сборке с `REVENUECAT_ANDROID_KEY=test_…`. Создайте Test Store products,
прикрепите к тому же entitlement и Current Offering. Это не настоящая оплата
Google Play. Test Store ключ не должен попасть в магазин.

## 4. Firebase и приватные видео

Проект Firebase: `kyrgyztest-app`. Перед развёртыванием проверьте активный проект
и наличие подходящего billing plan для Cloud Functions/Secret Manager.

Следуйте [настройке видео](video_lessons_setup.md). Секрет `VIDEO_ACCESS_CONFIG`
содержит MinIO read-only key и **RevenueCat V1 Secret API key**. Мобильная
конфигурация не содержит эти значения. Secret API key должен относиться к тому
же проекту RevenueCat, что и мобильный public SDK key.

Для настоящих платежей backend отклоняет sandbox-покупки. Для теста добавьте
**только свои тестовые Firebase UID** в серверную настройку:

```json
"revenueCat": {
  "apiKey": "REVENUECAT_V1_SECRET_API_KEY",
  "entitlementId": "KyrgyzTest Pro",
  "sandboxUserIds": ["YOUR_TEST_FIREBASE_UID"]
}
```

Этот массив позволяет проверять Test Store/Play license purchases только этим
аккаунтам. Он не выдаёт Premium без активной покупки RevenueCat. После тестов
удалите тестовые UID либо оставьте только контролируемые аккаунты для QA.
Коллекция `premium_access` и клиентский `users.isPremium` теперь не дают доступ.

Из корня проекта, после сохранения секрета:

```bash
firebase use kyrgyztest-app
firebase deploy --only functions:getVideoLessons,functions:getVideoPlaybackUrl
```

Не разворачивайте все функции без необходимости. Текущие Firestore Rules не
хранятся в репозитории: сначала сохраните действующие правила и проверьте их
в Firebase Console. Клиентам нельзя разрешать редактировать каталог `videos`
или служебные поля доступа. Не заменяйте правила всей базы шаблоном.

После успешной оплаты функции проверяют подписку на сервере и выдают ссылки
на 15 минут. При ошибке RevenueCat доступ закрыт. Обычная ссылка MinIO должна
по-прежнему возвращать `403 AccessDenied`.

## 5. Политики, аккаунт и карточка магазина

До production нужны реальные общедоступные HTTPS-страницы:

| Параметр сборки | Содержание |
| --- | --- |
| `PRIVACY_POLICY_URL` | Владелец, собираемые данные, Firebase, RevenueCat, обработка эссе/аудио, сроки хранения и контакты |
| `TERMS_URL` | Условия использования и подписки, продление, отмена, доступ к материалам |
| `ACCOUNT_DELETION_URL` | Рабочая форма или способ запроса удаления без установки приложения; название KyrgyzTest, данные и порядок удаления |
| `SUPPORT_EMAIL` | Подтверждённый, регулярно проверяемый адрес поддержки |

Кнопки добавлены в «Аккаунт и конфиденциальность». Приложение открывает запрос
или **черновик** письма, не удаляет аккаунт автоматически и не отправляет
письмо самостоятельно. Владелец должен организовать реальную обработку
запросов. Удаление аккаунта не отменяет store subscription.
См. [порядок обработки удаления](account_deletion_operations.md).

Заполните Data safety, возраст/целевую аудиторию, рейтинг, рекламу, privacy URL
и deletion URL по действительному поведению приложения. Проверьте SDK и
серверную обработку эссе; не копируйте ответы «данные не собираются».
Для модерации подготовьте действующий аккаунт/инструкции с доступом ко всем
платным разделам через допустимый RevenueCat доступ. Также нужны иконка,
скриншоты, feature graphic, описание и контакты правообладателя.

## 6. Подписать и собрать Android App Bundle

Используйте Flutter **3.38.4 или новее**, Android SDK 36 и JDK 17.
Target API установлен в **36**. Debug-signing для release удалён.
При отсутствии upload keystore релизная Gradle-сборка завершается ошибкой.

Если upload keystore уже существует, используйте его. Для первого релиза
создавайте новый только после проверки, что приложение ещё не связано с
другим ключом/аккаунтом Play. Сохраните ключ и пароли в защищённом месте с
резервной копией.

Пример команды создания нового ключа **для первого релиза**:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Скопируйте `android/key.properties.example` в `android/key.properties`, заполните
его локально. Скопируйте `config/android-release.example.json` в
`config/release.json` и задайте public SDK key и реальные ссылки. Эти локальные
файлы игнорируются Git. Не добавляйте туда MinIO/RevenueCat server credentials.

```bash
flutter pub get
dart run tool/check_release_config.dart config/release.json
flutter analyze
flutter test
flutter test --dart-define=DESIGN_PREVIEW=true
flutter build appbundle --release --dart-define-from-file=config/release.json
```

`check_release_config` проверяет формат/отсутствие test key и секретных полей,
но не подтверждает работоспособность страниц или настройку внешних кабинетов.
Перед новой загрузкой увеличьте build number в `pubspec.yaml`.
Итог: `build/app/outputs/bundle/release/app-release.aab`.

После включения Play App Signing добавьте SHA-1/SHA-256 **app signing key** из
Play Console в Firebase Android app и проверьте Google Sign-In из сборки,
установленной через магазин. Отпечаток upload key и ключа, которым Play
подписывает установку, могут различаться.

## 7. Обязательная проверка на устройстве

Загрузите AAB в Internal testing и установите приложение по ссылке Google
Play. Настройте License testing для своих Google-аккаунтов: реальные данные
карты для обычного пользователя могут привести к настоящей покупке.

- [ ] Гость видит приглашение войти, а не сетевую ошибку.
- [ ] Покупка/отмена покупки/ошибка сети показывают корректный результат.
- [ ] Активная подписка открывает приватное видео и превью.
- [ ] Плеер воспроизводит MP4, перемотка и возвращение из фона работают.
- [ ] Повторный запуск сохраняет Premium того же Firebase UID.
- [ ] Восстановление работает после переустановки для того же аккаунта.
- [ ] Выход и другой Firebase-аккаунт не наследуют платный доступ.
- [ ] Подписка после отмены действует до конца оплаченного срока.
- [ ] Истечение, refund/revocation и account hold закрывают доступ; grace period сохраняет доступ, пока действует.
- [ ] Privacy/terms открываются, запрос удаления действительно обрабатывается.
- [ ] A1–C1, четыре сферы, связанные разделы, русский/кыргызский, тесты и аудио проверены.
- [ ] Pre-launch report не содержит блокирующих сбоев.
- [ ] Для личного нового аккаунта выполнен необходимый закрытый тест.

CI проверяет Flutter анализ/тесты, demo-тесты, debug APK и серверную авторизацию.
Он не подписывает production AAB, не делает покупок и не публикует приложение.

## Официальные инструкции

- [Регистрация Google Play](https://support.google.com/googleplay/android-developer/answer/6112435)
- [Тестирование новых личных аккаунтов](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Target API](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Удаление аккаунтов](https://support.google.com/googleplay/android-developer/answer/13327111)
- [RevenueCat: конфигурация SDK и Test Store](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [RevenueCat: Google Play credentials](https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials)
- [RevenueCat: восстановление покупок](https://www.revenuecat.com/docs/getting-started/restoring-purchases)
- [Flutter: Android release signing](https://docs.flutter.dev/deployment/android)
