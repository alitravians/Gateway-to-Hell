local GameConfig = {}

GameConfig.GameTitleAr = "بوابة الجحيم"
GameConfig.GameTitleEn = "Gateway to Hell"
GameConfig.TaglineAr = "تعاون، اكشف الأسرار، واهرب قبل أن تُغلق البوابة."
GameConfig.COUNTDOWN_SECONDS = 5
GameConfig.PLAYER_COUNT_OPTIONS = { 2, 4, 6 }
GameConfig.DEFAULT_MODE_ID = "Story"
GameConfig.STORY_REGION_ORIGIN = Vector3.new(2000, 0, 0)
GameConfig.STORY_KEY_COUNT = 5
GameConfig.SECRET_OBJECTIVE_ID = "PortalSecret"
GameConfig.MODE_TIME_LIMITS = {
    Story = 900,
    Nightmare = 780,
    Hardcore = 660,
    Endless = 1200,
}

GameConfig.MODE_TUNING = {
    Story = {
        Monster = {
            SpeedMultiplier = 1,
            VisionRange = 80,
            HearingRange = 60,
            CatchRange = 5,
            SearchRelocateMin = 120,
            SearchRelocateMax = 180,
        },
        Hiding = {
            DwellMin = 45,
            DwellMax = 90,
        },
        Flashlight = {
            BatteryDrainPerSecond = 1.8,
            BatteryPickupAmount = 35,
        },
        Sanity = {
            DarkDrainPerSecond = 1.0,
            MonsterDrainPerSecond = 2.5,
            RecoveryPerSecond = 1.4,
            HiddenDrainPerSecond = 0.2,
            LowThreshold = 30,
        },
        Gameplay = {
            AllowRevive = true,
            EndlessPressure = false,
        },
    },
    Nightmare = {
        Monster = {
            SpeedMultiplier = 1.25,
            VisionRange = 95,
            HearingRange = 75,
            CatchRange = 5.5,
            SearchRelocateMin = 90,
            SearchRelocateMax = 135,
        },
        Hiding = {
            DwellMin = 35,
            DwellMax = 70,
        },
        Flashlight = {
            BatteryDrainPerSecond = 2.2,
            BatteryPickupAmount = 30,
        },
        Sanity = {
            DarkDrainPerSecond = 1.4,
            MonsterDrainPerSecond = 3.3,
            RecoveryPerSecond = 1.0,
            HiddenDrainPerSecond = 0.3,
            LowThreshold = 35,
        },
        Gameplay = {
            AllowRevive = true,
            EndlessPressure = false,
        },
    },
    Hardcore = {
        Monster = {
            SpeedMultiplier = 1.15,
            VisionRange = 90,
            HearingRange = 72,
            CatchRange = 5.75,
            SearchRelocateMin = 75,
            SearchRelocateMax = 120,
        },
        Hiding = {
            DwellMin = 30,
            DwellMax = 60,
        },
        Flashlight = {
            BatteryDrainPerSecond = 2.5,
            BatteryPickupAmount = 25,
        },
        Sanity = {
            DarkDrainPerSecond = 1.5,
            MonsterDrainPerSecond = 3.8,
            RecoveryPerSecond = 0.8,
            HiddenDrainPerSecond = 0.35,
            LowThreshold = 35,
        },
        Gameplay = {
            AllowRevive = false,
            EndlessPressure = false,
        },
    },
    Endless = {
        Monster = {
            SpeedMultiplier = 1.08,
            VisionRange = 88,
            HearingRange = 70,
            CatchRange = 5.5,
            SearchRelocateMin = 60,
            SearchRelocateMax = 95,
        },
        Hiding = {
            DwellMin = 25,
            DwellMax = 50,
        },
        Flashlight = {
            BatteryDrainPerSecond = 2.0,
            BatteryPickupAmount = 40,
        },
        Sanity = {
            DarkDrainPerSecond = 1.2,
            MonsterDrainPerSecond = 2.9,
            RecoveryPerSecond = 1.2,
            HiddenDrainPerSecond = 0.25,
            LowThreshold = 30,
        },
        Gameplay = {
            AllowRevive = true,
            EndlessPressure = true,
            EndlessPulseSeconds = 90,
        },
    },
}

GameConfig.GAME_MODES = {
    {
        Id = "Story",
        NameAr = "القصة",
        NameEn = "Story",
        DescriptionAr = "تقدم تعاوني متدرج مع ألغاز وأحداث رعب مركزة.",
    },
    {
        Id = "Nightmare",
        NameAr = "الكابوس",
        NameEn = "Nightmare",
        DescriptionAr = "أعداء أكثر شراسة، ضباب أثقل، ومخاطر أعلى على الفريق.",
    },
    {
        Id = "Hardcore",
        NameAr = "القاسي",
        NameEn = "Hardcore",
        DescriptionAr = "لا رحمة تقريبًا: موارد محدودة وأخطاء أقل مسموحة.",
    },
    {
        Id = "Endless",
        NameAr = "اللانهاية",
        NameEn = "Endless",
        DescriptionAr = "أطول صمود ممكن مع تصاعد تدريجي في التهديدات.",
    },
}

GameConfig.COLORS = {
    Background = Color3.fromRGB(12, 8, 18),
    Panel = Color3.fromRGB(24, 14, 22),
    PanelSoft = Color3.fromRGB(34, 18, 28),
    Accent = Color3.fromRGB(210, 74, 38),
    AccentAlt = Color3.fromRGB(255, 140, 77),
    AccentDim = Color3.fromRGB(115, 34, 28),
    Text = Color3.fromRGB(244, 236, 242),
    TextMuted = Color3.fromRGB(187, 173, 183),
    Danger = Color3.fromRGB(182, 48, 36),
}

GameConfig.SURVIVAL_TIPS = {
    "ابقَ قريبًا من الفريق؛ الظلام يفرّق من يبقى وحيدًا.",
    "استمع للأصوات المنخفضة قبل أن تدخل أي ممر جديد.",
    "لا تجري في خطوط مستقيمة عند سماع فلاشات الرعب.",
    "تبادل الإضاءة والمراقبة بين اللاعبين لتقليل المفاجآت.",
    "إذا تغيّر الضوء فجأة، توقّف واستمع لثانيتين.",
}

GameConfig.MONSTER_LORE = {
    "الكيان الأصلي لا يظهر كاملًا؛ الباقي يتركه الخوف للخيال.",
    "أبواب الحديد القديمة لا تفتح باليد، بل بالهمس والندم.",
    "كل خطوة في القبو القديمة ترد عليك بصدى ليس لك.",
    "النجاة ليست أن تهرب أسرع؛ النجاة أن تعرف متى لا تنظر.",
}

GameConfig.CHANGELOG = {
    "v0.1 — تجهيز اللوبّي، شاشة التحميل، والقائمة الرئيسية.",
    "v0.1 — نظام المطابقة 2/4/6 مع عدّاد دخول أولي.",
    "v0.1 — لوحة أفضل اللاعبين وتهيئة بيانات الحفظ.",
}

GameConfig.PLACEHOLDER_ASSET_IDS = {
    LobbyMesh = 0,
    MenuBackdrop = 0,
    MonsterSilhouette = 0,
    LobbyMusic = 0,
    WindLoop = 0,
}

GameConfig.PLACEHOLDER_SOUND_IDS = {
    ChaseMusic = 0,
    Heartbeat = 0,
    DownedLoop = 0,
    MonsterStinger = 0,
    Whispers = 0,
}

GameConfig.PLACEHOLDER_BADGE_IDS = {
    FirstEscape = 0,
    NoDeathsEscape = 0,
    NightmareClear = 0,
    HardcoreClear = 0,
    SecretEnding = 0,
}

GameConfig.ENDING_LINES = {
    Good = {
        TitleAr = "نهاية النجاة",
        LineAr = "أبواب الجحيم تنحني أمام الناجين، لكن صدى الخطوات ما زال خلفهم.",
    },
    Bad = {
        TitleAr = "النهاية المظلمة",
        LineAr = "لم يبقَ سوى الصمت… والجدران تردد أسماء من غابوا.",
    },
    Secret = {
        TitleAr = "النهاية السرية",
        LineAr = "تكشف البوابة سرها لمن يجرؤ على لمس الطقس المظلم ثم يهرب حيًا.",
    },
}

GameConfig.UPDATE_SECTIONS = {
    {
        TitleAr = "المحتوى الجديد",
        Items = {
            "ألغاز القبو الخمسة أصبحت كاملة وتفتح البوابة بعد حلها.",
            "حارس الجحيم يطاردك بعد انتهاء الوقت مع حالات منطرح/إنعاش.",
            "نظام الاختباء والمصباح والبطاريات يضيف طبقة بقاء متواصلة.",
        },
    },
    {
        TitleAr = "المواقع",
        Items = {
            "القصر الرئيسي في اللوبي مع البوابة الحجرية والمركز الملعون.",
            "منطقة القبو البعيدة مع ممرات الغموض والغرفة السرية.",
        },
    },
    {
        TitleAr = "الصوت والإضاءة",
        Items = {
            "طبقات مطاردة جديدة، أنين منخفض، وتأثيرات صفاء/تشوش حسب الحالة.",
            "توازن ضوء المصباح مع بطاريات قابلة للتجديد وتأثيرات سمعية خفيفة.",
        },
    },
}

GameConfig.LOADING_MESSAGES = {
    Title = "جارٍ فتح البوابة...",
    Subtitle = "تهيئة عناصر الرعب التعاوني وتحميل القاعة الرئيسية.",
}

function GameConfig.getModeById(modeId: string)
    for _, mode in ipairs(GameConfig.GAME_MODES) do
        if mode.Id == modeId then
            return mode
        end
    end

    return nil
end

return GameConfig
