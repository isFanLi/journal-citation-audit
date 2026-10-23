# journal-citation-audit · 期刊引用统计

一个可安装的 Codex Skill：查找指定作者在指定时间范围发表的论文，检查其参考文献是否引用目标期刊，逐条累加并填写统计表。

An installable Codex skill for auditing references to a target journal in an author's publications, with selectable publication-date rules and traceable citation counts.

## 快速开始

安装后，在支持本地技能的 Codex 对话中发送：

```text
$journal-citation-audit
```

技能会先在聊天中返回以下空白模板，你复制、填写后发送即可。这是文本模板，技能本身不会创建原生弹窗。

```text
用 $journal-citation-audit 统计引用。
作者：
单位：
时间：YYYY-MM-DD 至 YYYY-MM-DD
目标期刊：完整刊名
日期口径：首次 online / 正式刊出 / 两者任一（选一）
模板：见附件；没有模板则写“生成简表”
已有论文清单/DOI/PDF：选填
特殊要求：选填
```

如果已经提供完整需求，技能会直接处理；已有的信息不用重填，缺少日期口径时会询问一次。

以下例子均为虚构数据，用于说明格式：

```text
用 $journal-citation-audit 统计引用。
作者：Author A、Author B
单位：Example University
时间：2026-07-01 至 2026-09-30
目标期刊：Journal of Example Engineering（虚构期刊）
日期口径：两者任一
模板：生成简表
```

## 安装

### 让技能安装器安装

在有 `$skill-installer` 的 Codex 中发送：

```text
用 $skill-installer 安装这个仓库里的技能：
https://github.com/isFanLi/journal-citation-audit/tree/main/skills/journal-citation-audit
```

发布脚本会自动将上面的仓库占位地址替换为实际地址。安装后在下一轮对话调用技能；如果客户端尚未加载它，可重新打开对话。

### 手动安装

下载仓库，将 `skills/journal-citation-audit` 整个目录复制到当前客户端识别的用户技能目录，保留 `SKILL.md` 和 `agents/openai.yaml`。不同版本可能使用 `~/.agents/skills` 或 `~/.codex/skills`，以客户端配置和[官方文档](https://learn.chatgpt.com/docs/build-skills)为准。

## 日期口径

| 选项 | 何时纳入 |
| --- | --- |
| 首次 online | 首次在线发表日期落入查询范围 |
| 正式刊出 | 正式刊出或编入卷期的日期落入查询范围 |
| 两者任一 | 两种日期任意一种符合；同一篇论文仍只计一次 |

例如：2025 年首次 online、2026 年 7 月正式刊出的论文，查询 2026 年 7—9 月时，只在后两种模式中纳入。没有选择口径时，技能会让用户选择。

卷期日期不等于首次 online 日期。Crossref 的创建、更新、索引日期也不等于发表日期。“两者任一”模式中一种日期已符合即可纳入；一种不符合、另一种未知时，交由用户检查。

**每篇候选都展示两种日期及其来源。** 选“两者任一”时，不能只写命中的那个日期；另一日期在范围外也照实列出。取不到的写明具体原因，不填空白或虚构日期。一种日期已确认命中、另一种未取得时，是“已纳入，另一日期待补”，不是整篇范围待核。

## 论文检索与日期界定 SOP

完整步骤及虚构案例见 [论文检索与日期界定 SOP](skills/journal-citation-audit/references/search-and-date-sop.md)。

1. **锁定身份与口径：**核实中文名、英文署名、有效变体、单位／ORCID、期刊全称和起止日期。
2. **建立候选并集：**结合作者／机构目录、出版商及可用数据库，同时覆盖中文与英文记录。选择“两者任一”时，既找当期 online 的论文，也找当期编入卷期的论文，避免漏掉更早年份 online 的文章。
3. **双日期取证：**逐篇查首次 online 和正式刊出，各自记录值、精度、来源及缺口；先确定纳入也不能省掉另一字段。
4. **独立判断：**分开记录范围状态、日期资料完整度、参考文献核查状态。按 DOI 去重，两种日期同时命中不加倍。
5. **交付可复查结果：**统计主表附双日期；另附全部候选的“论文与日期核查”明细及简短检索说明，交代来源、日期规则、排除原因和待核项。

## 统计规则与交付

- 多位作者默认按“任一作者署名”合并检索，共同署名的论文去重。
- 一篇施引论文引用 3 篇目标期刊文献，计 3；两篇施引论文各引用同一篇目标期刊文献，合计 2。
- 同篇正文多次引用同一篇文献只计一次。
- 列出被引文献与对应施引论文，优先填写用户提供的 Excel；也可按要求生成简表。
- 结果同时展示首次 online、正式刊出及各自来源，写明纳入依据；模板无日期列时补入施引文章栏，并在核查附页保留完整记录。
- 核查附页涵盖无引用及待核的候选；检索说明写明使用的来源、中文／英文署名、日期发现路径、范围和去重方式。
- 无法确认日期、作者身份或完整参考文献时，交付已确认部分，并列明待核内容、原因和需要用户检查的材料。

## 数据来源与限制

优先读取出版社提交到 Crossref 的公开记录：

```text
https://api.crossref.org/works/{DOI}
```

主要查看 `message.reference` 和 `message.reference-count`，结合刊名、引用缩写和 DOI 核对。并非每篇论文都提交了完整参考文献；缺失或不完整不能解释为“引用为 0”。必要时查出版商参考文献页或用户提供的 PDF。

本项目是一套代理执行指令，不包含独立搜索服务、付费数据库权限或电子表格引擎。实际检索、文件编辑和网络访问使用所在客户端可用的工具。Skill 不单独运行，不要求提交 API 密钥。

参考：[Codex 技能文档](https://learn.chatgpt.com/docs/build-skills)、[Crossref REST API](https://www.crossref.org/documentation/retrieve-metadata/rest-api/)。

## 一键发布自己的仓库

在 Windows 上双击 `publish.cmd`，或运行：

```powershell
.\publish.ps1
```

脚本会检查待发布文件、准备 GitHub CLI、引导 GitHub 网页登录、新建公开仓库 `journal-citation-audit` 并推送。需要本机已安装 Git；若没有 GitHub CLI，脚本只在系统临时目录下载官方便携版本，不修改系统 PATH。GitHub 网页授权需要你本人完成，不要把密码或 Token 发进聊天。

可指定自己的账号或组织及仓库名：

```powershell
.\publish.ps1 -Owner YOUR_ACCOUNT -RepositoryName journal-citation-audit
```

只检查本地文件，不登录、不建仓库、不推送：

```powershell
.\publish.ps1 -CheckOnly
```

同一目录再次运行会推送这些公开文件的后续修改；如果同名远程仓库已存在、但本地尚未与它绑定，脚本会停止，避免误写已有仓库。

### 公开内容与隐私

发布脚本只暂存明确列出的项目文件；不收集或上传真实任务的附件、论文清单、统计表、聊天记录、凭据或本地路径。提交作者使用通用署名和占位邮箱，不读取全局 Git 作者信息。不要往公开说明中加入自己的敏感数据。

GitHub 仓库所属的账号名，以及 GitHub 记录的推送身份仍会公开。需要账号层面隔离时，请在网页授权阶段选择专用账号。

## 仓库结构

```text
README.md
LICENSE
.gitignore
publish.cmd
publish.ps1
skills/journal-citation-audit/
  SKILL.md
  agents/openai.yaml
  references/search-and-date-sop.md
```

## License

[MIT](LICENSE)。允许使用、修改和分发，保留许可及版权声明。
