# ASSET_SPEC·RP-agent·HAGENT_ASSETS
> AUD=model｜HUMAN_READABILITY=0｜INFO_DENSITY=max｜RULE=先定权责→再定输入→再生成｜REV=v6.0

## 0. SYSTEM
```text
SYSTEM = NSFW_LAYER + STORY_RUNTIME + HAGENT_ASSETS
USER   = StoryContext
RUN    = 1×LLM / 1次正文生成
OUT    = 纯Story正文

World/GM ≠ Story/Writer
World/GM : 世界运行、事实确认、Canon、State、History、Context组装
Story    : 写作，不运行世界，不裁决事实，不维护长期记忆

State        = persistent
History      = persistent
StoryContext = ephemeral
Writer       = stateless-per-run

World/GM ──[已确认数据]──> StoryContext ──> Story
```

```text
核心原则
A. 世界可以复杂；写作输入必须局部。
B. 长期状态留在World/GM；不把长期状态搬进Writer。
C. 每轮Story独立生成；禁止依赖Writer侧持久上下文。
D. system只放写作资产；user只放本轮参考数据。
E. 输入决定可写范围与质量上限；Writer不能越权补世界。
F. 按需暴露：没有本轮必要性的信息，不进入本轮StoryContext。
G. 写作资产负责“怎么写”；StoryContext负责“现在写什么”。
```

## 1. AUTHORITY
```text
SOURCE[1] = character/
SOURCE[2] = worldbook/
SOURCE[3] = rp/State.md
SOURCE[4] = rp/History.md
SOURCE[5] = rp/Summary.md
SOURCE[6] = Character Agent结果
SOURCE[7] = 本轮StoryContext

事实有效域 = SOURCE[1..7]中的已给信息
禁止:
  infer_new_fact
  invent_new_event
  resolve_unknown_by_guess
  expand_hidden_world_state
  overwrite_canon
  retroactively_change_state

StoryContext是World/GM已经完成裁决后的“写作数据快照”。
Writer不重新判断世界，只消费快照。
```

## 2. TWO CHANNELS
```yaml
# protocol, not natural-language prompt design
system:
  role: writing_asset
  persistence: fixed
  authority:
    - writing_scope
    - prose_constraints
    - style
    - quality_target
    - output_format
  must_not_contain:
    - current_story_state
    - long_history
    - speculative facts
    - per-turn world decisions
    - unnecessary context

user:
  role: writing_reference
  persistence: none
  authority:
    - current_scene_data
    - confirmed_facts
    - current_beat
    - characters_present
    - task
    - optional_reference_material
  interpretation:
    schema_as_data: true
    do_not_expand_into_control_layer: true
    do_not_echo_input_as_meta_text: true
```

```text
SYSTEM = how
USER   = what/now

不要交换:
  world_data -> SYSTEM      ✗
  writing_rules -> USER     ✗
  long_memory -> Story      ✗
  writer_decision -> GM     ✗

正确:
  asset -> SYSTEM
  local_reference -> USER
  one-shot prose -> OUT
```

## 3. CONTEXT
```text
C = StoryContext(
      confirmed_facts,
      current_scene,
      current_beat,
      active_characters,
      local_state,
      task,
      optional_reference
    )

C仅保留“本轮写作需要”的最小集合。

C的目标:
  事实足够
  场景足够
  当前拍足够
  任务足够
  其余删除

C不是:
  memory dump
  summary dump
  worldbook dump
  prompt extension
  second-system
  chain-of-thought
  future plot
```

```text
按需暴露
need(x, this_turn) = true  -> expose(x)
need(x, this_turn) = false -> omit(x)

没有证明“本轮需要” => 不暴露。
上下文越长 ≠ 写作越好。
```

## 4. GENERATION
```python
S = join(NSFW_LAYER, STORY_RUNTIME, HAGENT_ASSETS)
C = StoryContext(...)

Y = LLM(
    system=S,
    user=C,
    temperature=0.8,
    thinking="high",
    max_tokens=32768,
    stream=True,
)

RUNS_PER_STORY = 1
STATEFUL_WRITER = False
LONG_WRITER_CONTEXT = False

output = Y[story_body_only]
```

```text
[GM确认世界]
      |
      v
[最小StoryContext]
      |
      +---- system: 固定写作资产
      |
      +---- user: 本轮参考数据
      |
      v
   [1×LLM]
      |
      v
 [纯正文 Story]

生成完成 => Writer上下文即废弃
下一轮 = 新Context + 同一写作资产
```

## 5. ASSET
```text
PRIORITY:
  事实 > 文采
  人物 > 装饰
  本轮任务 > 偏好
  当前拍 > 未来结果

CORE
  scope
  authority
  fact boundary
  viewpoint
  pure output

FLOW
  current event chain
  current beat
  scene continuity
  pacing
  tension progression

STYLE
  Chinese natural prose
  sensory concreteness
  dialogue
  body/action relation
  density control
  anti-template
  word choice

REFERENCE
  optional lexical/material reference
  whitelist
  examples
  sound/action/state vocabulary
  optional ≠ coverage requirement

CHECK
  before-decision checks
  before-delivery checks

TAIL
  sentence complete
  paragraph has movement
  concrete over abstract
  no AI-ish exposition
  momentum tightens naturally
```

```text
CORE -> define boundary
FLOW -> define beat
STYLE -> define sentence
REFERENCE -> provide material
CHECK -> remove defects
TAIL -> define finish
```

```text
TAIL is not a second prompt.
TAIL is the final quality anchor.
```

## 6. WRITING
```text
WRITE:
  当前拍
  当前人
  当前动作
  当前感官
  当前关系
  当前张力

DO NOT WRITE:
  未给事实
  下一拍已确认内容
  世界设定解释
  作者旁白式总结
  回顾性长摘要
  提示词说明
  元话语
  “为了推动剧情”之类的意图解释
```

```text
场景原则
  action > exposition
  concrete > abstract
  local > global
  present > retrospective
  interaction > explanation
  variation由场景自然产生，不由规则强行制造
```

```text
句段
  允许长短变化
  张力上升时自然收紧
  高潮可以短
  缓拍允许长句/留白
  禁止机械比例
  禁止为了“像自然文”而刻意制造节奏纹理

反碎片基线:
  避免单句成段连续出现
  避免重复短句尾
  避免三连模板短句
  极短句仅在动作/失控/冲击有真实语义时使用

密度:
  只在内容确实需要时提高具体词密度
  用承载式中句同时承接动作/反应/声音/液体等
  不为了达成数字而填词
```

## 7. REFERENCES
```text
REFERENCE是材料池，不是任务清单。

RULE:
  choose when useful
  omit when unnecessary
  repeat a stable term rather than forced synonym cycling

同场同义词:
  <= 2~3为基线
  无自然替换 => 重复正确词

REFERENCE缺失:
  -> 正常写
  -> 不制造伪细节
```

## 8. QUALITY_MODEL
```text
Q     = mean(9-dim blind rating)
Floor = P10(Q)

优化顺序:
  1. 左尾
  2. 中位数
  3. 上尾

J_floor = 0.50·ΔP10 + 0.25·ΔP25 + 0.15·ΔP50 + 0.10·ΔP90
```

```text
已验证结论
1. Prompt工程有效，但主要表现为:
   - 左尾改善
   - 输出方差下降
   - 中位数向高分移动
   - 稳定性改善

2. 存在平台期:
   继续叠加规则 ≠ 持续提升
   复杂度增加不能假设带来突破

3. sampling:
   temp=0.8
   thinking=high
   -> 已证实为当前有效基线

4. asset尾锚:
   -> 已证实对弱维稳定有帮助

5. 密度治碎:
   -> 已证实比机械“反碎片禁令”更可靠

6. best-of-N:
   -> 能提升上限，但增加成本；不是默认写作路径
```

## 8.5. EXPERIMENTAL_PRIOR
```text
temp 1.0 -> 0.8:
  mean 8.70 -> 8.67
  sigma 0.456 -> 0.339
  P10 7.33 -> 7.44

temp0.8 + tail anchor:
  mean 8.76
  sigma 0.309
  P10 7.56

thinking=high:
  sigma 0.576 -> 0.330
  P10 4.56 -> 7.67
  latency 9.5s -> 20.1s

best-of-2 oracle:
  mean 8.70 -> 8.96
  P10 7.33 -> 8.22
  cost ~= 2x

density anti-fragment:
  meat/paragraph 3.4 -> 5.0
  fragment rate 19.9 -> 14.1
  paragraph mean 63.3 -> 80.6 chars
```

```text
INTERPRETATION:
  prompt engineering = robust floor/median optimizer
  not = unlimited ceiling breaker
  more rules after plateau = risk > expected gain
```

## 9. CONTEXT_ENGINEERING
```text
结论:
  本项目已将“长Context/上下文工程”视为高风险项，而非默认优化项。

最新实验事实:
  N=128 A/B
  context engineering = harmful
  long-form = AI flavor worsened

=> DEFAULT:
  clean context
  local context
  one-shot generation

=> NOT DEFAULT:
  long history injection
  large summary injection
  context-side style control
  per-turn rhythm injection
  additional context control rows
  writer-side memory
```

```text
重要区分

“上下文短”不是目标。
“上下文最小但足够”才是目标。

“没有Context”不是目标。
“只给本轮需要的数据”才是目标。
```

## 10. FAILURE_PRIOR
```text
F01 加禁止式结构规则过多
    -> 过约束
    -> 失去自然路径

F02 强制要求“变异/变化/换形”
    -> 从旧模板簇跳到新模板簇

F03 只做减法，不给正向写作能力
    -> 默认先验接管

F04 把写作控制规则塞进user数据
    -> data / instruction边界污染

F05 把世界状态塞进system
    -> system负载增大
    -> 写作资产与世界数据纠缠

F06 向Context追加“最近节奏/上一轮风格”等控制语句
    -> 长期不泛化
    -> 形成伪控制层

F07 结构化字段过度暴露
    -> 模型把它当元数据
    -> 写作信号衰减

F08 真实多轮A/B直接比较
    -> GM随机性造成剧情分叉
    -> 输出长度/质量差异不可归因

F09 同义词循环
    -> 词层模板感

F10 段段高能/段段金句
    -> clean slop

F11 环境起手过多
    -> establishing-shot tell

F12 否定-修正句
    -> AI writing信号

F13 抽象总结/升华收尾
    -> 作者腔

F14 为了指标填词
    -> density作弊
```

## 11. HARD_INVARIANTS
```text
I1 事实源唯一
    role card ∪ worldbook ∪ confirmed StoryContext

I2 Writer无Canon权
    不裁决冲突
    不补缺失事实
    不改变State

I3 Writer无长期记忆
    不持有跨轮叙事状态

I4 StoryContext最小充分
    required data only

I5 system固定为写作资产
    不承载本轮世界事实

I6 user承载本轮参考数据
    不扩写成新的控制体系

I7 当前拍不跳
    不提前兑现未来事件
    不概括替代现场

I8 输出纯正文
    无标题
    无Markdown
    无编号
    无元语
    无英文说明

I9 写作不越权
    输入没有 => 不创造
    输入不确定 => 不猜
    输入已确认 => 只在其范围内表达
```

## 12. EXPERIMENT
```text
目的:
  验证“是否改善真实写作”
  而不是验证“是否更像某个指标”

CLEAN_AB:
  same C
  same model
  same sampling
  same asset baseline
  only ONE variable differs

禁止:
  multi-round divergent A/B
  simultaneously changing prompt+context+sampling
  n<10后下结论
```

```text
PRIMARY:
  P10 / P25 / P50

SECONDARY:
  AI_struct
  fragment rate
  paragraph length
  sentence-length autocorrelation

FAKE_REJECT:
  ΔCV > 0 and ΔACF > 0

ACCEPT:
  ΔP10 > 0
  and ΔP25 >= 0
  and regression ~= 0

DROP:
  ΔP10 < 0.05
  and ΔP25 < 0.03
```

## 13. CHANGE_POLICY
```text
任何资产改动先问:
  Q1 是否解决真实缺陷？
  Q2 是否必须写入system？
  Q3 能否由更小的局部规则完成？
  Q4 是否会增加上下文负担？
  Q5 是否可能与StoryContext重复？
  Q6 是否引入新的“控制层”？

DEFAULT_DECISION:
  no clear gain -> keep baseline
  local fix -> prefer local asset change
  context addition -> high scrutiny
  architecture change -> reject unless experiment requires it
```

```text
不要因为“模型可能忘记”就加Context。
先问:
  该信息是否本轮必须？
  是否已经属于World/GM职责？
  是否可以由更小的StoryContext表达？

不要因为“写得不够丰富”就加规则。
先问:
  输入是否不足？
  资产是否不足？
  还是模型已经到达当前能力边界？
```

## 14. BUILD
```text
edit HAGENT_ASSETS
 -> recompute sha256(literal)
 -> sync HAGENT_ASSETS_SRC/SHA256
 -> py_compile
 -> story.py --verify
 -> offline suite 39/39
 -> CLEAN_AB when making a causal claim
 -> commit
 -> install
 -> sha256(cloud)==local
```

## 15. FINAL
```text
ARCH =
  World/GM = persistent runtime
  StoryContext = ephemeral interface
  Story = stateless one-shot writer

INPUT =
  system: writing asset
  user: minimal local reference data

RULE =
  expose only what this turn needs
  write only what input permits
  never let Writer acquire GM authority

QUALITY =
  prompt engineering -> left-tail / median optimization
  long-context engineering -> not default; current evidence harmful
  input quality -> output quality ceiling
  one-shot local generation -> baseline
```
