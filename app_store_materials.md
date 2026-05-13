# QuickCards App Store Listing Materials

## App Store (iOS)

### App Name
QuickCards

### Subtitle
Smart Flashcard Learning App

### Description (English)
QuickCards is a powerful flashcard app with intelligent spaced repetition (SRS) that helps you learn and retain knowledge effectively.

**Features:**
- Create unlimited decks and flashcards
- Import cards from CSV files easily
- Smart SRS algorithm optimizes your review schedule
- Track your learning progress with detailed statistics
- Set daily goals and new card limits
- Clean, modern Material Design 3 interface

**How it works:**
1. Create a deck for any subject (languages, science, history, etc.)
2. Add cards with front/back content
3. Import cards from CSV files (front,back,tags format)
4. Review cards daily - the app shows you what you need to learn
5. Track your streak and progress over time

Download QuickCards now and start learning smarter!

### Description (Chinese)
QuickCards 是一款强大的闪卡应用，采用智能间隔重复算法（SRS），帮助你高效学习和记忆知识。

**功能特点：**
- 创建无限数量的卡组和闪卡
- 轻松从 CSV 文件导入卡片
- 智能 SRS 算法优化复习计划
- 通过详细统计跟踪学习进度
- 设置每日目标和新卡片数量限制
- 简洁现代的 Material Design 3 界面

**使用流程：**
1. 为任何科目创建卡组（语言、科学、历史等）
2. 添加正面/背面内容的卡片
3. 从 CSV 文件导入卡片（格式：正面,背面,标签）
4. 每天复习 - 应用展示你需要学习的内容
5. 跟踪你的连续学习天数和进度

立即下载 QuickCards，开始更智能地学习！

### Keywords
flashcard, learning, study, vocabulary, language, education, memory, srs, spaced repetition, cards, quiz, test, school, college, chinese, japanese, spanish, french, german

### Category
Education

### Pricing
$0.99 (one-time purchase)

### Privacy Policy URL
Required - can use a free privacy policy generator like:
- https://appprivacypolicy.com/
- https://privacygenerator.io/

### Screenshots Required (5)
1. Home screen with deck list
2. Deck detail with cards
3. Card review screen (question side)
4. Card review screen (answer side)
5. Statistics/progress screen

### App Icon
Use the default Flutter icon or create a custom one (1024x1024 for App Store)

---

## Google Play Store (Android)

### App Name
QuickCards

### Short Description
Smart flashcard app with spaced repetition for effective learning

### Full Description
QuickCards is a powerful flashcard app with intelligent spaced repetition (SRS) that helps you learn and retain knowledge effectively.

**Features:**
- Create unlimited decks and flashcards
- Import cards from CSV files easily
- Smart SRS algorithm optimizes your review schedule
- Track your learning progress with detailed statistics
- Set daily goals and new card limits
- Clean, modern Material Design 3 interface

**How it works:**
1. Create a deck for any subject (languages, science, history, etc.)
2. Add cards with front/back content
3. Import cards from CSV files (front,back,tags format)
4. Review cards daily - the app shows you what you need to learn
5. Track your streak and progress over time

Download QuickCards now and start learning smarter!

### Category
Education

### Pricing
$0.99 USD (one-time purchase)

### Privacy Policy URL
Same as App Store

### Screenshots Required
Phone: 2-8 screenshots (16:9 or 9:16)
- Home screen with deck list
- Deck detail with cards
- Card review screen
- Statistics screen

### Feature Graphic
Required: 1024x500px
Optional: 180x120px for TV banner

---

## CSV Import Format

```
front,back,tags
Hello,Hola,spanish;greetings
Goodbye,Adiós,spanish;greetings
Thank you,Gracias,spanish;politeness
```

- First row must be header: `front,back,tags`
- Fields separated by commas
- Multiple tags separated by semicolons
- UTF-8 encoding recommended

---

## iOS Submission Without Mac

Options for submitting to App Store without a Mac:

1. **Codemagic** (Recommended)
   - Free tier available
   - Connects to GitHub
   - Automatically builds iOS from source
   - https://codemagic.io

2. **GitHub Actions with macOS runner**
   - Requires paid GitHub plan
   - Can rent macOS runners per minute

3. **MacStadium**
   - Rent a Mac in the cloud
   - Pay per hour

4. **Transporter Web**
   - After getting IPA from CI/CD
   - Upload directly at transporter.apple.com