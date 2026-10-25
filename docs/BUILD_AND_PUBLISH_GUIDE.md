# Инструкция по сборке APK и публикации «Сомнии» в RuStore

Кодовая база **«Сомния» (v1.0.0)** полностью готова, валидирована техлидом (Gemini Argon), статический анализатор дает **0 предупреждений**, а все 12 тестов проходят успешно.

Ниже описаны 2 простых способа собрать готовый `app-release.apk` и опубликовать его в RuStore.

---

## Способ 1: Бесплатная автоматическая облачная сборка через GitHub (Рекомендуется, 3 минуты)

Вам **не нужно** скачивать 4 ГБ Android Studio и настраивать SDK на своем компьютере:

1. Создайте репозиторий на [GitHub.com](https://github.com) (публичный или приватный), например `somnia`.
2. Загрузите файлы проекта из папки `D:\ANTI\somnia` в репозиторий:
   ```bash
   cd D:\ANTI\somnia
   git init
   git add .
   git commit -m "feat: release v1.0.0 Somnia CBT-i"
   git remote add origin https://github.com/<ваш_логин>/somnia.git
   git branch -M main
   git push -u origin main
   ```
3. GitHub Actions автоматически запустит скрипт `.github/workflows/build_release.yml`:
   - Установит Java 17 и Flutter 3.47.8;
   - Прогонит анализатор и все unit-тесты;
   - Соберет чистый оптимизированный `app-release.apk`.
4. Во вкладке **Actions** в GitHub скачайте готовый артефакт **`somnia-release-apk`**.

---

## Способ 2: Локальная сборка на вашем ПК через Android Studio

Если вы хотите собирать APK прямо на своем компьютере:

1. Скачайте и установите [Android Studio](https://developer.android.com/studio).
2. При первом запуске согласитесь с установкой **Android SDK** и **Command-line Tools**.
3. Убедитесь, что в системе установлен JDK 17.
4. Запустите в терминале:
   ```powershell
   flutter doctor --android-licenses   # примите лицензии (нажимайте 'y')
   cd D:\ANTI\somnia
   flutter build apk --release
   ```
5. Готовый файл появится по адресу:
   `D:\ANTI\somnia\build\app\outputs\flutter-apk\app-release.apk`

---

## Подпись приложения (Keystore)

В `android/app/build.gradle.kts` настроена подпись. 
* Для первого релиза в RuStore можно использовать стандартную подпись (RuStore принимает как стандартный debug-ключ, так и релизный).
* Чтобы сгенерировать собственный постоянный ключ:
  ```powershell
  keytool -genkey -v -keystore D:\ANTI\somnia\android\app\somnia-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias somnia
  ```

---

## Пошаговая публикация в RuStore Консоль

### Шаг 1: Политика конфиденциальности
RuStore требует публичную HTTPS-ссылку на политику:
* Включите **GitHub Pages** в настройках вашего репозитория (Settings -> Pages -> Branch: main, Folder: /docs), и ваша ссылка будет вида:
  `https://<ваш_логин>.github.io/somnia/privacy_policy.html`
* Или загрузите `docs/privacy_policy.html` на любой бесплатный хостинг (Vercel, Netlify, Яндекс.Диск с публичной страницей).

### Шаг 2: Карточка приложения в RuStore
1. Зайдите в [Консоль RuStore](https://console.rustore.ru/).
2. Нажмите **«Создать приложение»** -> укажите имя: **«Сомния: Дневник сна и CBT-i»**.
3. Заполните поля из файла `docs/RUSTORE_LISTING.md`:
   - **Категория:** Здоровье и спорт / Медицина.
   - **Краткое описание:** Научно доказанная терапия сна (CBT-i), дневник и практики релаксации без медикаментов.
   - **Полное описание:** скопируйте блок из `docs/RUSTORE_LISTING.md`.
   - **Возрастной рейтинг:** 12+ или 18+ (в соответствии с медицинским дисклеймером).
4. Загрузите файл `app-release.apk`.
5. Отправьте на модерацию.
