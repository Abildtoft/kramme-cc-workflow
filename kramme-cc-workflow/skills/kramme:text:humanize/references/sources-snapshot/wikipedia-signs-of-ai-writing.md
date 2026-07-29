{{redirect|Wikipedia:AI writing|identifying comments in discussions|Wikipedia:Signs of AI-generated comments|other uses|Wikipedia:Artificial intelligence resources}}
{{pp-vandalism|small=yes}}
{{WikiProject advice|wikiproject=WikiProject AI Cleanup|WP:AISIGNS|WP:AITELLS|WP:LLMSIGNS}}
[[File:ChatGPT response screenshot 1.jpg|thumb|alt=A screenshot of ChatGPT reading: "[header] Legacy & Interpretation [body] The "Black Hole Edition" is not just a meme — it's a celebration of grassroots car culture, where ideas are limitless and fun is more important than spec sheets. Whether powered by a rotary engine, a V8 swap, or an imagined fighter jet turbine, the Miata remains the canvas for car enthusiasts worldwide."|LLMs tend to have an identifiable writing style.]]
This is a list of writing and formatting conventions typical of [[AI chatbot]]s such as [[ChatGPT]], with real examples taken from Wikipedia articles, drafts, comments, and other content. It is a [[field guide]] to help detect [[WP:LLMDISCLOSE|undisclosed AI-generated content]] ''on Wikipedia'': while some of the signs may be broadly applicable, some may not apply in a non-Wikipedia context.{{efn|Specifically, this guide is less useful for texts which are not informational writing. For example, the many tells specific to fiction (whispering woods, [https://maxread.substack.com/p/who-is-elara-voss Elara Voss], etc.) are less relevant in Wikipedia and are not listed here.}} Not all text featuring these indicators is AI-generated, as the [[large language model]]s that power AI chatbots are trained on human writing, including Wikipedia. Many elements of AI writing can be found in editorials, blogs, or fan fiction.

Moreover, this list is {{em|descriptive}}, not {{em|prescriptive}}; it consists of observations, not rules. Advice about formatting or language to avoid can be found in the [[Wikipedia:PAG|policies and guidelines]] and the [[Wikipedia:MOS|Manual of Style]], but does not belong on this page.

'''The patterns listed here are also only potential {{em|signs}} of a problem, not {{em|the problem itself}}.''' While many of these issues are immediately obvious and easy to fix{{--}}e.g., excessive boldface, broken markup, citation style quirks{{--}}they can point to less outwardly visible problems that carry [[WP:AIFAIL|much more serious policy risks]]. '''Please do not merely treat these signs as the problems to be fixed; that could just make detection harder.''' The actual problems are those deeper concerns, so make sure to address them, either yourself or by flagging them, per the [[Wikipedia:WikiProject AI Cleanup/Guide|relevant guide]].

The [[Wikipedia:Speedy deletion|speedy deletion policy]] criterion [[WP:G15|G15]] (LLM-generated pages without human review) lists some signs of AI writing, but is limited to the most objective ones. The remaining signs covered here are not sufficient on their own for speedy deletion.

==Caveats==
===AI detection tools===
{{shortcut|WP:AIDETECTION}}
Do not solely rely on [[artificial intelligence content detection]] tools (such as [[GPTZero]]). While they perform better than random chance, these tools have non-trivial error rates.<ref name="Russell" /><ref name="dik2025">{{cite journal |last1=Dik |first1=Selin |last2=Erdem |first2=Osman |last3=Dik |first3=Mehmet |title=Assessing GPTZero's Accuracy in Identifying AI vs. Human-Written Essays |journal=arXiv |date=2025 |arxiv=2506.23517 }}</ref> Detectors can be susceptible to factors such as text modifications (e.g. paraphrasing, markup, and spacing changes) and the use of models not seen during detector training.<ref>{{cite conference|last1=Dugan|first1=Liam|last2=Hwang|first2=Alyssa|last3=Trhlik|first3=Filip|last4=Zhu|first4=Andrew|last5=Ludan|first5=Josh Magnus|last6=Xu|first6=Hainiu|last7=Ippolito|first7=Daphne|last8=Callison-Burch|first8=Chris|title=RAID: A Shared Benchmark for Robust Evaluation of Machine-Generated Text Detectors|conference=Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)|year=2024|pages=12463–12492|location=Bangkok, Thailand|publisher=Association for Computational Linguistics|arxiv=2405.07940|url=https://aclanthology.org/2024.acl-long.674|access-date=2025-11-08|archive-date=2025-08-24|archive-url=https://web.archive.org/web/20250824132743/https://aclanthology.org/2024.acl-long.674/|url-status=live}}</ref> A high percentage of detected AI writing from the results of a detection tool is '''not''' a valid criterion for speedy deletion under G15.

===Your detection ability===
{{Shortcut|WP:AIDETECTIVE}}
{{ombox|image=none|style=background-color: light-dark(#FFEFFC, #1E0517); color: light-dark(#202122, #eaecf0); height: 4em;|textstyle=text-align: center;|text='''Test your AI detection skills at [[Wikipedia:AI or not quiz]].'''}}
Do not rely too much on your own judgment. Humans are notoriously bad at distinguishing human and LLM-generated text. While research on humans' abilities to detect AI-generated text is still limited, a 2025 study has shown that human ability to distinguish LLM text from human is no better than random chance.<ref name="cheng2025">{{cite journal |last1=Cheng |first1=Adam |last2=Lin |first2=Yiqun |last3=Reedy |first3=Gabriel |last4=Joseph |first4=Christine |last5=Wirkowski |first5=Samantha |last6=Mallette |first6=Viviane |last7=Nagesh |first7=Vikhashni |last8=Krieser |first8=David |last9=Calhoun |first9=Aaron |title=Ability of AI detection tools and humans to accurately identify different forms of AI-generated written content |journal=Advances in Simulation |date=2025 |volume=10 |issue=1 |article-number=66 |doi=10.1186/s41077-025-00396-6 |doi-access=free |pmid=41272826 |pmc=12752165 }}</ref> Another 2025 study on German theses has shown that humans managed a "recognition rate of 57 % for AI texts and 64 % for human-generated texts".<ref name="fiedler2025">{{cite journal |last1=Fiedler |first1=Alexandra |last2=Döpke |first2=Jörg |title=Do humans identify AI-generated text better than machines? Evidence based on excerpts from German theses |journal=International Review of Economics Education |date=2025 |volume=49 |article-number=100321 |doi=10.1016/j.iree.2025.100321 }}</ref>

A 2025 preprint has shown that heavy users of LLMs can correctly determine whether an article was generated by AI about 90% of the time, which means that if you are an expert user of LLMs and you tag 10 pages as being AI-generated, you've probably made one false positive. Study participants who didn't use LLMs much did only slightly better than random chance (in both directions).<ref name="Russell" />

Note, also, that human speech and writing is being influenced by LLMs, and thus they are becoming more similar. This was already evident in 2024, as shown by a study that detected a significant LLM influence in spoken content (e.g. conversational podcasts).<ref name="yakura2024">{{cite journal |last1=Yakura |first1=Hiromu |last2=Lopez-Lopez |first2=Ezequiel |last3=Brinkmann |first3=Levin |last4=Serna |first4=Ignacio |last5=Gupta |first5=Prateek |last6=Soraperra |first6=Ivan |last7=Rahwan |first7=Iyad |title=Empirical evidence of Large Language Model's influence on human spoken communication |date=2024 |arxiv=2409.01754 |journal=arXiv}}</ref> Further studies seem to confirm this influence on language,<ref name="geng2025">{{cite book |last1=Geng |first1=Mingmeng |last2=Chen |first2=Caixi |last3=Wu |first3=Yanru |last4=Wan |first4=Yao |last5=Zhou |first5=Pan |last6=Chen |first6=Dongping |title=Findings of the Association for Computational Linguistics: ACL 2025 |chapter=The Impact of Large Language Models in Academia: From Writing to Speaking |date=2025 |pages=19303–19319 |doi=10.18653/v1/2025.findings-acl.987 }}</ref> including semantics and word choices.<ref name="galpin2025">{{cite journal |last1=Galpin |first1=Riley |last2=Anderson |first2=Bryce |last3=Juzek |first3=Tom S. |title=Exploring the Structure of AI-Induced Language Change in Scientific English |journal=The International Flairs Conference Proceedings |date=2025 |volume=38 |doi=10.32473/flairs.38.1.138958 |arxiv=2506.21817 }}</ref>

It is also worth noting that writers may adjust their behavior to avoid accusations of AI, or may be defensive about using AI tropes.

==Content==
{{Shortcut|WP:AIWTW|WP:AI-ISM|WP:LLMISM}}

LLMs (and [[artificial neural network]]s in general) use statistical algorithms to guess (infer) what should come next based on a large corpus of training material. It thus tends to [[regression to the mean|regress to the mean]]; that is, the result tends toward the most statistically likely result that applies to the widest variety of cases. It can simultaneously be a strength and a "tell" for detecting AI-generated content.

For example, LLMs are usually trained on data from the internet in which famous people are generally described with positive, important-sounding language. Consequently, the LLM tends to omit specific, unusual, nuanced facts (which are statistically rare) and replace them with more generic, positive descriptions (which are statistically common). Thus the highly specific "inventor of the first train-coupling device" might become "a revolutionary titan of industry". It is like shouting louder and louder that a portrait shows a uniquely important person, while the portrait itself is fading from a sharp photograph into a blurry, generic sketch. The subject becomes simultaneously less specific and more exaggerated.{{efn|This can be directly observed by examining images generated by [[text-to-image model]]s; they look acceptable at first glance, but specific details tend to be blurry and malformed. This is especially true for background objects and text.}}

This statistical regression to the mean, a smoothing over of specific facts into generic statements, that could equally apply to many topics, makes AI-generated content easier to detect.

===Undue emphasis on significance, legacy, and broader trends ===
{{shortcut|WP:AILEGACY|WP:AITREND}}
{{tmbox|image=none|text=Words to watch: {{strong|''stands/serves as'', ''is a testament/reminder'', ''a crucial/pivotal/vital/significant/key role/moment'', ''underscores/highlights its importance/significance'', ''reflects broader'', ''symbolizing its ongoing/enduring/lasting'', ''contributing to the'', ''setting the stage for'', ''marking/shaping the'', ''represents/marks a shift'', ''key turning point'', ''evolving landscape'', ''focal point'', ''indelible mark'', ''deeply rooted'', &nbsp;...}}}}
LLM writing often [[Wp:puffery|puffs up]] the importance of the subject matter by adding statements about how arbitrary aspects of the topic represent or contribute to a broader topic.<ref name="chronicle"/><ref name="sun" /> There is a distinct and easily identifiable repertoire of ways that it writes these statements.<ref name="Juzek" />

'''Examples'''
{{collapse top|expand=yes|From [[Special:Diff/1252053288|this September 2024 revision]] to [[Statistical Institute of Catalonia]]}}
The Statistical Institute of Catalonia was officially established in 1989, {{highlight|marking a pivotal moment}} in the evolution of regional statistics in Spain. [...]

The founding of Idescat {{highlight|represented a significant shift}} toward regional statistical independence, enabling [[Catalonia]] to develop a statistical system tailored to its unique socio-economic context. This initiative {{highlight|was part of a broader movement}} across Spain to decentralize administrative functions and enhance regional governance.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1248482444|this October 2024 revision]] to [[Kumba, Cameroon]]}}
Kumba has long been {{highlight|an important center}} for trade and agriculture. [...] The establishment of road networks connecting Kumba to other parts of the Southwest Region, such as Mamfe and Buea, helped {{highlight|solidify its role as a regional hub}}.
{{collapse bottom}}

Another common manifestation of this sign is AI chatbots situating an article subject amid broader "debates" or "discussions".

{{collapse top|From [[Special:Diff/1317624451|this October 2025 revision]] to [[Deadbot]]}}
The phenomenon has {{highlight|generated debate}} about authenticity, consent, and the psychological effects of digitally extending personhood.

[...]

Collectively, these works have {{highlight|shaped emerging policy discussions}} about ownership, consent, and dignity in digital resurrection technologies.

[...]

GriefBots have {{highlight|prompted broader reflection}} on mortality and memory in a digital age. They blur boundaries between life and data, {{highlight|raising philosophical questions}} about identity, authenticity, and what it means to “live on” through algorithms.
{{collapse bottom}}

LLMs may even include these statements for even the most mundane of subjects like etymology or population data. Sometimes, they add hedging preambles acknowledging that the subject is of relatively low importance, before talking about its importance anyway.

{{blockquote|text=During the [[Spanish Colonial Period (Philippines)|Spanish colonial period]], the name ''Bakunutan'' was hispanized to ''Bacnotan'', a modification reflected in official documents preserved in the [[National Archives of the Philippines|National Archives]] in Manila. {{highlight|This etymology highlights the enduring legacy}} of the community's resistance and {{highlight|the transformative power}} of unity in shaping its identity.|title=From [[Special:Diff/1265870147|this December 2024 revision]] to [[Bacnotan]]}}

{{blockquote|text={{highlight|Though it saw only limited application}}, it {{highlight|contributes to the broader history}} of early aviation engineering and {{highlight|reflects the influence of French rotary designs}} on German manufacturers.|title=From [[Wikipedia:Signs of AI writing/Examples/Goebel Goe II|Draft:Goebel Goe II]] (July 2025)}}

When talking about biology (e.g., when asked to discuss an animal or plant species), LLMs tend to over-emphasize connections to the broader ecosystem or environment, even when those connections are tenuous or generic. LLMs also tend to belabor the species' conservation status and research and preservation efforts, even if the status is unknown and no serious efforts exist.

{{blockquote|text=Currently, {{highlight|there is no specific conservation assessment}} for ''Lethrinops lethrinus'' by the International Union for Conservation of Nature (IUCN). However, the general health of the Lake Malawi ecosystem is {{highlight|crucial for the survival of this and other endemic species}}. Factors such as overfishing, pollution, and habitat destruction could potentially impact their populations.
|title=From [[Special:Diff/1235454313|this July 2024 revision]] to [[Lethrinops lethrinus]]}}

{{blockquote|text=It {{highlight|plays a role in the ecosystem}} and {{highlight|contributes to Hawaii's rich cultural heritage}}. [...] {{highlight|Preserving this endemic species is vital}} not only for ecological diversity but also for sustaining the cultural traditions connected to Hawaii’s native flora.|title=From [[Special:Diff/1262033910|this December 2024 revision]] to [[Nototrichium divaricatum]]}}

===Canned emphasis on notability, attribution, and media coverage===
{{shortcut|WP:OVERATTRIBUTION|WP:AIATTR}}{{anchor|Attribution}}
{{tmbox|image=none|text=Words to watch: {{strong|''independent coverage'', ''local/regional/national/[country name] media outlets'', ''music/business/tech outlets'', ''trade publications'', ''profiled in'', ''written by a leading expert'', ''active social media presence''}}}}
Similarly, LLMs act as if the best way to prove that a subject is notable is to hit readers over the head with claims of notability, often by listing sources that a subject has been covered in and specifying what kind of sources they are (e.g., trade publications, regional media, etc). They often inaccurately attribute their own [[#Superficial analyses|superficial analyses]] to the source. This is more common in text from AI tools released in 2025 or later.

Human-written press releases have of course also cited news clippings for decades, but LLMs specifically asked to write a Wikipedia article often echo the exact wording of [[WP:N|Wikipedia's guidelines]], such as "independent coverage."

'''Examples'''
{{collapse top|From [[Special:Diff/1276225083|this February 2025 revision]] to [[Sinead Bovell]]}}
She spoke about AI on CNN, and was {{highlight|featured in}} Vogue, Wired, Toronto Star, and {{highlight|other media}}.
[...]
Her insights have also been {{highlight|featured in}} *Wired*, *Refinery29*, and {{highlight|other prominent media outlets}}.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1294930957|this June 2025 revision]] to [[Virginia High School (Minnesota)]]}}
Its significance is {{highlight|documented in archived school event programs and regional press coverage}}, including the *Mesabi Daily News*, which regularly reviewed performances held there.
{{collapse bottom}}

{{collapse top|From [[Wikipedia:WikiProject Articles for creation/Help desk/Archives/2025 November 2#06:02, 2 November 2025 review of submission by Moefry1|this November 2025 AfC help desk comment]]}}
The subject has been {{highlight|profiled in multiple high-quality, independent, and widely-read outlets}}, including The Australian, SBS News, 7News, and coverage syndicated through the Associated Press—{{highlight|appearing in platforms}} like The Senior and Perth Now. These sources provide {{highlight|significant, substantial, secondary coverage}}, not trivial mentions or press releases.
----
• {{highlight|Repeated national media coverage}} for both professional and advocacy work ({{highlight|reported by}} SBS, 7News, The Australian, etc.) • Leadership roles in international and national health campaigns (e.g., THINK Aorta ANZ and board member of Hearts4Heart) • National ambassador role for the National Heart Foundation of Australia, {{highlight|highlighted by multiple independent reports}} • Academic and economic contributions {{highlight|recognised by universities, specialist publications, and health system institutions}} (e.g., University of Sydney, Monash University, RANZCR) • {{highlight|Ongoing public presence in respected media}} and at speaking events over multiple years, including via {{highlight|independent news commentary, landmark survival stories, and national health initiatives}} Together, these factors clearly demonstrate {{highlight|significant, sustained, and verifiable coverage}}—meeting both WP:BIOSIGand WP:SIGCOV.
{{collapse bottom}}

On Wikipedia specifically, LLMs often painstakingly emphasize their sources in the body text—even for trivial coverage, uncontroversial facts, or other situations where a human Wikipedia editor would be more likely to either provide an inline citation or no source at all.

'''Examples'''
{{blockquote|text=The restaurant {{highlight|has also been mentioned in [[ABC News (Australia)|ABC News]] coverage relating to}} incidents in the surrounding precinct, underscoring its role as a well-known late-night venue in the city [of [[Adelaide]]].|title= Trivial coverage with attribution, from  [[Special:Permalink/1305163154|this August 2025 revision]] to [[The Original Pancake Kitchen]]; the reference added for this sentence did not exist.}}

In articles about people or entities that use social media, LLMs will often note that they "maintain an active social media presence" or something similar. This wording is particularly idiosyncratic to AI text and relatively uncommon on Wikipedia before ~2024.

'''Examples'''
{{blockquote|The mall {{highlight|maintains a strong digital presence}}, particularly on Instagram, where it actively shares the latest updates and events. Forum Kochi has consistently demonstrated excellence in digital promotions, with high-quality, engaging, and impactful video content playing a key role in its outreach.|From [[Special:Diff/1297291381|this June 2025 revision]] to [[Forum Mall Kochi]]}}

===Superficial analyses===
{{shortcut|WP:SUPERFICIAL}}
{{tmbox|image=none|text=Words to watch: {{strong|''highlighting/underscoring/emphasizing ...'', ''ensuring ...'', ''reflecting/symbolizing ...'', ''contributing to ...'', ''cultivating/fostering ...'', ''encompassing ...'', ''enhancing ...'', ''valuable insights'', ''align/resonate with'', }} }}
AI chatbots tend to insert superficial analysis of information, often in relation to its significance, recognition, or impact.<ref name="Reinhart">{{cite journal |last1=Reinhart |first1=Alex |last2=Markey |first2=Ben |last3=Laudenbach |first3=Michael |last4=Pantusen |first4=Kachatad |last5=Yurko |first5=Ronald |last6=Weinberg |first6=Gordon |last7=Brown |first7=David West |title=Do LLMs write like humans? Variation in grammatical and rhetorical styles |journal=[[Proceedings of the National Academy of Sciences]] |volume=122 |issue=8 |date=2025-02-25 |issn=0027-8424 |pmc=11874169 |doi=10.1073/pnas.2422455122 |url=https://pnas.org/doi/10.1073/pnas.2422455122 |access-date=2026-01-29}}</ref> This is often done by attaching a [[Participle#Forms|present participle]] ("-ing") phrase at the end of sentences, sometimes with [[WP:AIWEASEL|vague attributions]] to third parties (see below).<ref name="Reinhart" /><ref name="chronicle"/>

For the purpose of Wikipedia, such comments are usually [[WP:SYNTH|synthesis]] or unattributed opinions. Newer chatbots with [[retrieval-augmented generation]] (for example, an AI chatbot that can search the web) may attach these statements to [[#Undue emphasis on notability, attribution, and media coverage|named sources]]—e.g., "Roger Ebert highlighted the lasting influence"—regardless of whether those sources say anything close.

'''Examples'''
{{collapse top|expand=yes|From {{diff||1161677884|label=this June 2023 revision}} to [[Douéra]]}}
As of the April 2008 census, the population of Douera stood at approximately 56,998 inhabitants, {{highlight|creating a lively community within its borders.}} Situated in the central-north region of the country, Douera enjoys close proximity to the capital city, Algiers, {{highlight|further enhancing its significance as a dynamic hub of activity and culture.}} With its coastal charm and convenient location, Douera captivates both residents and visitors alike, {{highlight|offering a diverse range of experiences against the backdrop of Algeria's stunning natural beauty.}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1240127604|this August 2024 revision]] to [[Darbhanga Junction railway station]]}}
It holds a pivotal place in the [[East Central Railway Zone]] of [[Indian Railways]], {{highlight|serving as a major railway hub with historical significance.}} The station has {{RailGauge|1676mm|lk=on}} [[broad gauge]] along with 8 tracks and 6 platforms. [...] Historically, it has been crucial for linking [[Darbhanga]] with significant cities like [[Delhi]], [[Patna]], and [[Kolkata]], {{highlight|facilitating the movement of passengers and goods.}} The station has supported various services, including passenger trains and express trains like the [[Satyagrah Express]] and [[Mithila Express]], {{highlight|contributing to the socio-economic development of the region.}} [...] Over the years, Darbhanga Junction has seen several upgrades and modernization efforts aimed at improving facilities and operational efficiency, {{highlight|reflecting its continued relevance in the regional and national transportation landscape.}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1253182873|this October 2024 revision]] to [[African-American culture]]}}
The civil rights movement emerged as a powerful continuation of this struggle, {{highlight|emphasizing the importance of solidarity and collective action in the fight for justice.}} This historical legacy has influenced contemporary African-American families, {{highlight|shaping their values, community structures, and approaches to political engagement.}} Economically, the enduring impacts of systemic inequality have led to both challenges and innovations within African-American communities, {{highlight|driving a commitment to empowerment and social change that echoes through generations.}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1256905241|this November 2024 revision]] to [[McAllen Texas Temple]]}}
Situated just a few miles from the U.S.-Mexico border—{{highlight|a line that often represents separation and division}}—the temple {{highlight|stands as a counter-symbol, emphasizing unity, togetherness, and transcendent faith.}} In a region where many families and communities span both countries, the temple {{highlight|fosters a sense of connection and shared purpose.}} Through its inclusive design and symbolic features, the McAllen Texas Temple is seen as a bridge across divides, {{highlight|embodying the spirit of unity that underlies its sacred purpose.}} Its bilingual monument sign, with inscriptions in both English and Spanish, {{highlight|underscores its role in bringing together Latter-day Saints}} from the United States and Mexico.

The temple’s architectural and decorative elements are thoughtfully imbued with local symbolism, {{highlight|reflecting the rich culture and landscape of the Rio Grande Valley.}} Citrus blossom motifs, seen throughout the exterior and interior, {{highlight|celebrate the area’s agricultural roots and its vital citrus industry.}} The temple’s color palette of blue, green, and gold {{highlight|resonates with the region’s natural beauty,}} symbolizing Texas bluebonnets, the Gulf of Mexico, and the diverse Texan landscapes. These colors and patterns {{highlight|evoke enduring faith and resilience, qualities that resonate deeply within this close-knit, cross-border community.}}

In design and structure, the McAllen Texas Temple {{highlight|honors the Spanish colonial heritage that has historically shaped the area.}} By incorporating these architectural elements, the temple connects to both the Latin American influences and the historic roots of the border region, {{highlight|creating a space where the past and present come together.}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1279776010|this March 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Jacques Blois (linguist)|Draft:Jacques Blois]]}}
These works are now part of the **Collections of the National Museum of Education - Réseau Canopé (France)**, {{highlight|highlighting their historical and pedagogical significance.}}

His influence persists in more recent studies. In 2010, ''Les néologismes dans l'hebdomadaire L'Express'' (1980) was cited in the ''Proceedings of the 1st International Congress on Neology in Romance Languages'' [...] {{highlight|demonstrating the ongoing relevance of his research on lexical evolution.}} [...] In 2004, the ''Cahiers de lexicologie'' (issues 84-87), published by the [[French National Centre for Scientific Research|CNRS]], cited the ''Grammaire Blois'', {{highlight|confirming its relevance in modern research.}} [...]

These citations, spanning more than six decades and appearing in recognized academic publications, {{highlight|illustrate Blois' lasting influence in computational linguistics, grammar, and neology.}}

Fridrichová analyzes the distinction made by Blois and Bar between acronyms, abbreviations, and truncations, {{highlight|emphasizing their critical view on the impact of truncations in the French language.}}

[...]

Fridrichová highlights that Blois and Bar perceive truncations as a **distortion of the language rather than an enrichment**, {{highlight|a perspective that still fuels linguistic debates today.}} This citation {{highlight|demonstrates the **enduring relevance of Blois's work in modern linguistic studies** and its **critical reception by researchers**.}}
}}
{{collapse bottom}}

{{collapse top|From [[Wikipedia:AI noticeboard#c-Munfarid1-20260726114900-Munfarid1-20260726113700|this July 2026 AI noticeboard comment]]}}
Answer: Here are several neutral, Wikipedia-style paraphrases:
<br>1. **Recommended:**<br>
> The cover of Columbia's Tunisian record supplement featured the popular Tunisian Jewish singer Louisa Tounsia, {{highlight|reflecting the public image that the record company sought to project.}}
<br>2. **More formal:**<br>
> Louisa Tounsia, one of Tunisia's most popular Jewish performers, appeared on the cover of Columbia's Tunisian record supplement, {{highlight|underscoring the image that the label aimed to cultivate.}}
<br>3. **Closer to the original:**<br>
Columbia's Tunisian record supplement featured Louisa Tounsia on its cover, {{highlight|highlighting the image that the record label wished to promote through its marketing.}}
{{collapse bottom}}

===<span class="anchor" id="Promotional language"></span>Promotional and advertisement-like language===
{{For|non-AI-specific guidance about this|Wikipedia:Manual of Style/Words to watch#Puffery}}
{{see also|Wikipedia:Marketing buzzspeak#Marketing buzzspeak and artificial intelligence}}
{{Shortcut|WP:AIPUFFERY|WP:AIPEACOCK}}
{{tmbox|image=none|text=Words to watch: {{strong|''boasts a'', ''vibrant'', ''rich'', ''profound'', ''enhancing'', ''showcasing'', ''exemplifies'', ''commitment to'', ''natural beauty'', ''nestled'', ''in the heart of'', ''groundbreaking'', ''renowned'', ''featuring'', ''diverse array'', &nbsp;...}}}}
LLMs have serious problems keeping a neutral tone. Even when prompted to use an encyclopedic style, their output will often tend toward advertisement-like writing, or like the prose of a travel guide. This may happen when generating new text or rewriting existing text: for instance, an edit summary claiming a rewrite "removed promotional tone" while actually introducing it. This may also happen when editors are not [[WP:COI|deliberately trying to advertise]] a subject.<ref name="rettberg">{{cite web |last1=Walker Rettberg |first1=Jill |title=Genre glitches and unexpected promotional phrases as a sign of AI writing |url=https://jilltxt.net/genre-glitches-and-unexpected-promotional-phrases-as-a-sign-of-ai-writing/ |website=jilltxt |access-date=13 May 2026}}</ref>

Note: Not all promotional or spammy writing is AI-generated. LLMs tend to over-use the same set of promotional phrases no matter what the topic. Also, older LLMs (e.g., GPT-4) tend to output more blatantly positive text<ref name="sussman">{{cite web |last1=Sussman |first1=Kristen |last2=Carter |first2=Daniel |title=Detecting Effects of AI-Mediated Communication on Language Complexity and Sentiment |url=https://arxiv.org/abs/2504.19556 |website=Companion Proceedings of the ACM Web Conference 2025 |publisher=arXiv |access-date=13 May 2026}}</ref> than newer LLMs, which are more subtly positive and tend to avoid obviously superlative statements like "the best."

====Subtypes====

When writing about something that could be considered "cultural heritage," LLMs [[#Undue emphasis on significance, legacy, and broader trends|constantly remind the reader of its importance]].

{{collapse top|From {{diff||1162718043|label=this June 2023 revision}} to [[Alamata (woreda)]]}}
{{highlight|Nestled}} within the {{highlight|breathtaking}} region of Gonder in Ethiopia, Alamata Raya Kobo {{highlight|stands as a vibrant town with a rich cultural heritage and a significant place}} within the Amhara region. {{highlight|From its scenic landscapes to its historical landmarks}}, Alamata Raya Kobo {{highlight|offers visitors a fascinating glimpse into the diverse tapestry}} of Ethiopia. In this article, we will explore the {{highlight|unique characteristics}} that make Alamata Raya Kobo {{highlight|a town worth visiting}} and shed light on {{highlight|its significance}} within the Amhara region.
{{collapse bottom}}

{{collapse top|From {{diff||1299567515|label=this July 2025 revision}} to [[Tamil Nadu Tourism Development Corporation]]}}
TTDC {{highlight|acts as the gateway}} to Tamil Nadu’s {{highlight|diverse attractions}}, seamlessly connecting the beginning and end of {{highlight|every traveller's journey}}. It offers {{highlight|dependable, value-driven experiences}} that showcase the state’s {{highlight|rich history, spiritual heritage, and natural beauty}}.
{{collapse bottom}}

When writing about people or companies, LLMs will often adopt a press-release or commercial-esque tone.

{{collapse top|From [[Special:Diff/1259548187|this November 2024 revision]] to [[Kenya Airways]]}}
These projects {{highlight|align with KQ's goals of reducing its environmental footprint, improving operational efficiency, and fostering community development through job creation.}} CEO Allan Kilavuka {{highlight|emphasized the airline's commitment to sustainability, customer focus, and Africa's prosperity through responsible corporate practices.}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1285549984|this April 2025 revision]] to [[Cadillac Sollei]]}}
The SOLLEI’s exterior design {{highlight|communicates a powerful emotional presence,
staying true to Cadillac's signature bold proportions.}} Its low, elongated silhouette is highlighted by a wide stance and an extended coupe door, {{highlight|which enhances accessibility to the spacious rear cabin.}} Smooth, uninterrupted surfaces and a pronounced A-line {{highlight|accentuate the vehicle’s overall length,}} while a sleek, low tail {{highlight|imparts a sense of refined dynamism.}} A mid-body line runs seamlessly from the headlamps to the taillights, {{highlight|reinforcing the car’s cohesive and elegant design.}} Traditional door handles have been replaced with discrete buttons, {{highlight|preserving the vehicle’s clean and modern profile.}} In a nod to Cadillac’s legacy of bold color choices, the exterior is finished in "Manila Cream"—a distinctive hue originally offered in 1957 and 1958. This heritage color has been thoughtfully revived and hand-painted by Cadillac artisans, {{highlight|showcasing the brand’s dedication to craftsmanship and historical reverence.}}
{{collapse bottom}}

===Vague attributions and overgeneralization of opinions===
{{For|non-AI-specific guidance about this|Wikipedia:Manual of Style/Words to watch#Unsupported attributions}}
{{Shortcut|WP:AIWEASEL}}
{{tmbox|image=none|text=Words to watch: {{strong|''Industry reports'', ''Observers have cited'', ''Experts argue'', ''Some critics argue'', ''several sources/publications'' (when only few sources are cited), ''such as'' (before exhaustive word lists), &nbsp;...}}}}
AI chatbots tend to attribute opinions or claims to some vague authority—a practice called [[weasel wording]].

'''Examples'''

{{quote|Due to its unique characteristics, the Haolai River is of interest to {{highlight|researchers and conservationists}}. Efforts are ongoing to monitor its ecological health and preserve the surrounding grassland environment, which is part of a larger initiative to protect China’s semi-arid ecosystems from degradation.
|title=From [[Special:Diff/1295362066|this June 2025 revision]] to [[Haolai River]]}}

{{quote|The Kwararafa (Kororofa) confederacy is {{highlight|described in scholarship}} as a shifting [[Benue valley]] coalition led by [[Jukun]] groups and incorporating a range of [[Middle Belt]] peoples. Because much of the historical record derives from [[Hausa]] chronicles, Bornu sources and oral tradition, {{highlight|modern researchers treat}} Kwararafa as a fluid political and cultural formation rather than a fixed state.
|From [[Special:Diff/1323819205|this November 2025 revision]] to [[Kwararafa Confederacy]]}}

AI chatbots also commonly exaggerate the quantity of sources that these opinions are attributed to. They may present views from one or two sources as widely held (often combined with the vague attributions above), mention the existence or opinion of multiple "reviewers" or "scholars" while only citing one person, or imply that lists of examples are non-exhaustive when the sources give no indication that other examples exist.

'''Examples'''
{{blockquote|
While Pakistan was not directly named, the reference to cross-border terrorism, {{highlight|according to Indian sources,}} was widely interpreted as aimed at Islamabad.<ref name ="Indian Express" group="overgen">{{Cite web |date=2025-07-07 |title=BRICS leaders condemn April 22 Pahalgam attack: On terror, zero tolerance |url=https://indianexpress.com/article/india/brics-leaders-condemn-jk-pahalgam-attack-on-terror-zero-tolerance-10110505/ |access-date=2025-07-10 |website=The Indian Express |language=en}}</ref>
|From [[Special:Diff/1299755238|this July 2025 revision]] to [[BRICS]]}}

{{blockquote|
{{highlight|Toy industry publications such as}} ''The Toy Insider'' and ''Mojo Nation'' have presented Rubik's WOWCube as a STEM-oriented platform that brings the Rubik's Cube "into the future" with motion controls and an open software ecosystem.<ref name="ToyInsider2025" group="overgen">{{cite web |date=31 October 2025 |title=Rubik’s WOWCube |url=https://thetoyinsider.com/products/rubiks-wow-cube/ |access-date=2 December 2025 |website=The Toy Insider}}</ref><ref name="Mojo2025" group="overgen">{{cite web |date=26 July 2025 |title=Cubios Inc teams with Spin Master for Rubik’s WOWCube gaming platform |url=https://www.mojo-nation.com/cubios-inc-teams-with-spin-master-for-rubiks-wowcube-gaming-platform/ |access-date=2 December 2025 |website=Mojo Nation}}</ref>|
From [[Special:Diff/1325377957|this December 2025 revision]] to [[Rubik's WOWCube]].}}
{{Reflist-talk|group=overgen}}

=== Outline-like conclusions about challenges and future prospects ===
{{tmbox|image=none|text=Words to watch: {{strong|''Despite its... faces several challenges...'', ''Despite these challenges'', ''Challenges and Legacy'', ''Future Outlook''&nbsp;...}}}}
Many LLM-generated Wikipedia articles include a "Challenges" section, which typically begins with a sentence like "Despite its [positive/promotional words], [article subject] faces challenges..." and ends with either a vaguely positive assessment of the article subject,<ref name="Russell"/> or speculation about how ongoing or potential initiatives could benefit the subject. Such paragraphs usually appear at the end of articles with a rigid outline structure, which may also include a separate section for "Future Prospects."

Note: This sign is about the rigid formula, not simply the mention of challenges or challenging.

'''Examples'''

{{collapse top|From [[Special:Diff/1189640895|this December 2023 revision]] to [[International economic law]]}}
{{fake section|level=2|Challenges and Future Directions}}
As the global economy continues to evolve, international economic law {{highlight|faces new challenges and opportunities.}} [...] The future of international economic law lies in its ability to {{highlight|adapt to these emerging trends|lightgreen}} and continue to facilitate a stable and equitable global economic order.
{{collapse bottom}}

{{collapse top|From {{diff||1201557771|label=this January 2024 revision}} to [[Hydrocarbon economy]]}}
The future of hydrocarbon economies {{highlight|faces several challenges,}} including[...] This section would speculate on {{highlight|potential developments|lightgreen}} and the changing landscape of global energy.
{{collapse bottom}}

{{collapse top|From {{diff||1218690551|label=this April 2024 revision}} to [[Korattur]]}}
{{highlight|Despite its industrial and residential prosperity, Korattur faces challenges}} typical of urban areas, including[...] With its {{highlight|strategic location and ongoing initiatives|lightgreen}}, Korattur {{highlight|continues to thrive|lightgreen}} as an integral part of the Ambattur industrial zone, embodying the synergy between industry and residential living.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1241301672|this August 2024 revision]] to [[Amu Television]]}}
Operating in the current Afghan media environment {{highlight|presents numerous challenges,}} including[...] {{highlight|Despite these challenges,|lightgreen}} Amu TV has managed to {{highlight|continue to provide a vital service|lightgreen}} to the Afghan population​​.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1277706730|this February 2025 revision]] to [[Pyroelectricity]]}}
{{highlight|Despite their promising applications, pyroelectric materials face several challenges}} that must be addressed for broader adoption. One key limitation is[...] {{highlight|Despite these challenges|lightgreen}}, the versatility of pyroelectric materials {{highlight|positions them as critical components|lightgreen}} for sustainable energy solutions and next-generation sensor technologies.
{{collapse bottom}}

{{collapse top|From {{diff||1279428086|label=this March 2025 revision}} to [[Panama Canal]]}}
{{highlight|Despite its success, the Panama Canal faces challenges}}, including[...] {{highlight|Future investments in technology, such as automated navigation systems, and potential further expansions could enhance the canal’s efficiency|lightgreen}} and maintain its relevance in global trade.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1297629115|this June 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Socio-cognitive engineering|Draft:Socio-cognitive engineering]]}}
For example, while the methodology supports transdisciplinary collaboration in principle, applying it effectively in large, heterogeneous teams {{highlight|can be challenging.}} [...]

SCE continues to evolve {{highlight|in response to these challenges.|lightgreen}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1363932615|this July 2026 revision]] to [[Draft:Spanish fashion]]}}
{{fake section|level=2|Sociology, sustainability, and {{highlight|future challenges}}}}
The {{highlight|main contemporary challenge}} facing the fashion industry in Spain is its environmental impact, stemming from the production volume of fast fashion. [...]

Complementing this, the sector relies on technological research centres, such as the Textile Technology Institute (Aitex) in the Valencian Community, to develop patents for fibre-to-fibre chemical recycling, eco-design processes, and low-water-impact dyeing. These advancements aim to reduce dependence on petroleum-derived synthetic fibres and virgin cotton, marking the sector's mandatory transition towards sustainable and traceable business models {{highlight|for the coming decades|lightgreen}}.
{{collapse bottom}}

===Leads treating Wikipedia lists or broad article titles as proper nouns ===
In AI-generated articles about topics with a title that is not a [[proper name]], such as a [[Wikipedia:Manual of Style/Lists|list]], the first sentence of the lead may introduce or define the article's title as if it were a standalone real-world entity. While the [[Wikipedia:Manual_of_Style/Lead_section#Format_of_the_first_sentence|MOS]] does allow such titles to be included at the beginning of the lead "in a natural way", these AI leads tend not to be so natural.

'''Examples'''

{{blockquote|{{highlight|'''Catchment area (health)''' refers to}} the geographic area from which a health facility, such as a hospital or clinic, draws its patients.|From [[Special:Diff/1248996099|this October 2024 revision]] to now-deleted article Catchment area (health)}}

{{blockquote|{{highlight|EuroGames editions is the chronological list}} of the biennial EuroGames, a European LGBT+ multi-sport event organized by the European Gay and Lesbian Sport Federation (EGLSF).|From [[Special:Diff/1299100685|this July 2025 revision]] to [[EuroGames editions]]}}

{{blockquote|{{highlight|The “'''List of songs about Mexico'''” is a curated compilation}} of musical works that reference Mexico its culture, geography, or identity as a central theme.|From [[Special:Diff/1300476090|this July 2025 revision]] to [[List of songs about Mexico]]}}

==Language and grammar==
AI-generated text displays consistent patterns in syntax, word choice, and sentence construction that human writing does not display to nearly the same degree. Conversely, it often struggles to match some syntactic and linguistic patterns characteristic of human writing. Some LLMs deviate more from human writing than others; for example, GPT-4o, the language model used by ChatGPT from May 2024 to August 2025, produces output with more variation from human writing than other contemporaneous language models.<ref name="Reinhart" /> Since these are linguistic patterns, they occur consistently regardless of the subject matter, which often gives AI-generated text an identifiable "voice".

=== High density of "AI vocabulary" words ===
{{Shortcut|WP:AIVOCAB|WP:AIWORDS}}
<!-- Please only add words to this box if their overuse is corroborated by at least one reliable, non-pop-science external source, and is seen on Wikipedia often too. -->
{{tmbox|image=none|text=Words to watch: {{strong|''Additionally'' (especially beginning a sentence),<ref name="geng" /><ref name="huang" /> ''align with'',<ref name="Juzek" /><ref name="Kobak" /> ''boasts'' (meaning "has"),<ref name="Juzek2" /> ''bolstered'',<ref name="Kobak" /> ''crucial'',<ref name="Russell" /><ref name="geng" /><ref name="huang" /> ''delve'',<ref name="Juzek" /><ref name="Kobak" /><ref name="Russell" /><ref name="Kriss">{{Cite web|last=Kriss|first=Sam|date=December 3, 2025|title=Why Does A.I. Write Like … That?|work=The New York Times|url=https://www.nytimes.com/2025/12/03/magazine/chatbot-writing-style.html|url-access=subscription|access-date=December 6, 2025}}</ref> ''emphasizing'',<ref name="Juzek" /><ref name="Kobak" /> ''enduring'',<ref name="Kobak" /> ''enhance'',<ref name="Kobak" /><ref name="Russell" /> ''fostering'',<ref name="Kobak" /><ref name="Russell"/> ''garner'',<ref name="Juzek" /><ref name="Kobak" /> ''highlight'' (as a verb),<ref name="Russell" /><ref name="Kriss"/> ''interplay'',<ref name="Kobak" /> ''intricate/intricacies'',<ref name="Juzek" /><ref name="Kobak" /><ref name="Reinhart" /><ref name="Kriss"/> ''key'' (as an adjective),{{citation needed|date=November 2025}} ''landscape'' (as an abstract noun),<ref name="Russell" /> ''meticulous/meticulously'',<ref name="Juzek2">{{cite web |last1=Juzek |first1=Tom S. |last2=Ward |first2=Zina B. |title=Word Overuse and Alignment in Large Language Models: The Influence of Learning from Human Feedback |url=https://arxiv.org/pdf/2508.01930 |access-date=27 February 2026}}</ref><ref name="Kobak" /> ''pivotal'',<ref name="Kobak" /><ref name="Russell" /> ''robust'', ''showcase'',<ref name="Juzek" /><ref name="Kobak" /><ref name="Kriss"/> ''tapestry'' (as an abstract noun),<ref name="Russell" /><ref name="Reinhart /><ref name="Kriss"/> ''testament'',<ref name="Russell" /> ''underscore'' (as a verb),<ref name="Juzek" /><ref name="Kobak" /><ref name="Russell" /><ref name="Kriss"/> ''valuable'',<ref name="geng" /> ''vibrant''<ref name="Reinhart" /> }} }}

Many studies have demonstrated that LLMs overuse specific words. These words started appearing far more frequently in text produced after 2022, when LLM chatbots became widely accessible.<ref name="Juzek">{{cite conference |last1=Juzek |first1=Tom S. |last2=Ward |first2=Zina B. |title=Why Does ChatGPT "Delve" So Much? Exploring the Sources of Lexical Overrepresentation in Large Language Models |conference=Findings of the Association for Computational Linguistics: ACL 2025 |publisher=[[Association for Computational Linguistics]] |date=2025 |arxiv=2412.11385 |url=https://aclanthology.org/2025.coling-main.426.pdf |access-date=October 13, 2025 |via=[[ACL Anthology]] |archive-date=January 21, 2025 |archive-url=https://web.archive.org/web/20250121111136/https://aclanthology.org/2025.coling-main.426.pdf |url-status=live }}</ref><ref name="Kobak">{{cite journal |last1=Kobak |first1=Dmitry |last2=González-Márquez |first2=Rita |last3=Horvát |first3=Emőke-Ágnes |last4=Lause |first4=Jan |title=Delving into LLM-assisted writing in biomedical publications through excess vocabulary |journal=[[Science Advances]] |volume=11 |issue=27 |date=2 July 2025 |issn=2375-2548 |pmid=40601754 |pmc=12219543 |doi=10.1126/sciadv.adt3813 |url=https://www.science.org/doi/10.1126/sciadv.adt3813 |access-date=21 November 2025}}</ref> They often co-occur in LLM output: where there is one, there are likely others.<ref name="Kousha">{{cite conference |last1=Kousha |first1=Kayvan |last2=Thelwall|first2=Mike |title=How much are LLMs changing the language of academic papers after ChatGPT? A multi-database and full text analysis|conference=ISSI 2025 Conference |date=2025 |arxiv=2509.09596 |url=https://arxiv.org/pdf/2509.09596|access-date=4 November 2025|archive-date=14 September 2025 |archive-url=https://web.archive.org/web/20250914165435/https://arxiv.org/pdf/2509.09596 |url-status=live}}</ref> While most of these studies have analyzed scientific abstracts or fiction, "AI vocabulary" words are also ubiquitous in LLM-based encyclopedias, such as [[Grokipedia]], and in AI-generated Wikipedia text. One or two of these words appearing in an edit may be coincidental, but an edit (post-2022) introducing lots of them, lots of times, is one of the strongest tells for AI use.

The words that LLMs overuse have changed over time. For instance, the word ''[[wikt:delve|delve]]'' was famously overused by ChatGPT in 2023 and early 2024, but became less frequent later in 2024, then dropped off sharply in 2025.<ref name="merrill">{{cite news |last1=Merrill |first1=Jeremy B. |last2=Chen |first2=Szu Yu |last3=Kumer |first3=Emma |title=What are the clues that ChatGPT wrote something? We analyzed its style. |url=https://www.washingtonpost.com/technology/interactive/2025/how-detect-chatgpt-em-dash/ |access-date=14 November 2025 |work=The Washington Post |date=13 November 2025}}</ref><ref name="geng">{{cite web |last1=Geng |first1=Mingmeng |last2=Trotta |first2=Roberto |title=Human-LLM Coevolution: Evidence from Academic Writing |url=https://aclanthology.org/2025.findings-acl.657.pdf |website=aclanthology.org |access-date=17 December 2025}}</ref> Below is a breakdown of which words frequently recur together during which LLM "era". While these are not hard cutoffs, they should give you a rough idea of how "earlier" vs "later" LLM output reads.

* '''2023 to mid-2024''' (GPT-4): ''Additionally'', ''boasts'', ''bolstered'', ''crucial'', ''delve'', ''emphasizing'', ''enduring'', ''garner'', ''intricate/intricacies'', ''interplay'', ''key'', ''landscape'', ''meticulous/meticulously'', ''pivotal'', ''underscore'', ''tapestry'', ''testament'', ''valuable'', ''vibrant''
* '''Mid-2024 to mid-2025''' (GPT-4o): ''align with'', ''bolstered'', ''crucial'', ''emphasizing'', ''enhance'', ''enduring'', ''fostering'', ''highlighting'', ''pivotal'', ''showcasing'', ''underscore'', ''vibrant''
* '''Mid-2025 and on''' (GPT-5): ''emphasizing'', ''enhance'', ''highlighting'', ''showcasing'' (plus words associated with [[#Undue_emphasis_on_notability,_attribution,_and_media_coverage|"Undue emphasis on notability, attribution, and media coverage"]])

The distribution of "AI vocabulary" is also somewhat different depending on the chatbot or LLM used.<ref name="Reinhart" /> Grok output is particularly idiosyncratic: it overuses superficially "scientific" words like ''causal'', ''empirical'', ''correlate'', and continues to overuse ''underscore'' as of 2026.

This section is to be taken as literally as possible: a word being overused by AI does ''not'' imply that its synonyms are also overused. Also, keep context in mind. For example, while the figurative use of "underscore" is ubiquitous in earlier AI text, the word can also refer to a literal underline mark or to [[incidental music]].

'''Examples'''
{{collapse top|From [[Special:Diff/1263234661|this December 2024 revision]] to [[Jameh Mosque of Ashtarjan]], which contains text pasted from [[Special:Diff/1263233100|this revision]] to [[User:Hodaalamri/Jameh Mosque of Ashtarjan]]}}
The inscriptions also offer {{highlight|valuable}} insights into the construction of the mosque. They record the names of the {{highlight|key}} craftsmen involved, including Mason Ahmad b. Muhammad, known as Haddad (the smith or iron-worker), and Hjajji Muhammad, the tile-cutter from [[Tabriz]]. These names {{highlight|highlight}} the collaborative nature of mosque construction and {{highlight|emphasize}} the contributions of skilled artisans. [...] For example, the repeated invocation of the names of Muhammad and the Twelve Imams in Kufic script {{highlight|highlights}} the Shi'ite character of the mosque and links its construction to the broader context of the Ilkhanid state's official adoption of Shi'ism under [[Öljaitü|Oljeitu]]. [...] This inscription, commissioned during the reign of the Aq Qoyunlu ruler Uzun Hasan, also {{highlight|underscores}} the {{highlight|enduring}} practice of pious patronage for mosque upkeep and renovation.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1292567688|this May 2025 revision]] to [[Somali people]]}}
Somali cuisine is an {{highlight|intricate}} and diverse fusion of a multitude of culinary influences, drawing from the rich {{highlight|tapestry}} of [[Arab cuisine|Arab]], [[Indian cuisine|Indian]], and [[Italian cuisine|Italian]] flavours. This culinary {{highlight|tapestry}} is a direct result of Somalia's longstanding heritage of {{highlight|vibrant}} trade and bustling commerce.
[...]

{{highlight|Additionally,}} a distinctive feature of Somali culinary tradition is the incorporation of [[camel]] [[meat]] and [[milk]]. They are considered a delicacy and serve as cherished and fundamental elements in the rich {{highlight|tapestry}} of Somali cuisine.
[...]

An {{highlight|enduring testament}} to the influence of [[Italian Somaliland|Italian colonial rule in Somalia]] is the widespread adoption of [[pasta]] and [[Lasagna|lasagne]] in the local culinary {{highlight|landscape}}, espicially in the south, {{highlight|showcasing}} how these dishes have integrated into the traditional diet alongside rice.
[...]

{{highlight|Additionally,}} Somali merchants played a {{highlight|pivotal}} role in the global coffee trade, being one of the first to export coffee beans.
{{collapse bottom}}

===Avoidance of basic copulatives ("is"/"are" phrases)===
{{tmbox|image=none|text=Words to watch: {{strong|''serves as/stands as/marks/functions as/operates as/represents [a]'', ''boasts/features/maintains/offers [a]'', ''refers to''}}}}

LLM-generated text often replaces simple constructions that use [[Copula (linguistics)|copula]]s such as ''is'' or ''are'' with constructions such as ''serves as a'' or ''mark the''. This pattern has been observed in GPT and Gemini models.<ref name="huang" /> One study documented an over 10% decrease in the usage of the words ''is'' and ''are'' in academic writing in 2023, with no major changes in their frequency before that.<ref name="geng2">{{cite web |last1=Geng |first1=Mingmeng |last2=Trotta |first2=Roberto |title=Is ChatGPT Transforming Academics' Writing Style? |url=https://arxiv.org/abs/2404.08627 |access-date=8 January 2026}}</ref> Similarly, LLMs prefer to use [[WP:BUZZ|marketing]]-related verbs like ''features'', ''offers'', and the like to their neutral synonym ''has''. (Note: Do not confuse this with ''has'' used in the [[pluperfect|past perfect]] form, as in ''has been featured''.) Sometimes--especially in more recent AI output--these constructions are more elaborate, e.g., ''ventured into politics as a candidate'' versus ''was a candidate'', or ''began his career as'' versus ''was''.

A similar decline in "is"/"are" constructions has been observed on Wikipedia, especially when controlling for lead paragraphs (which usually follow a formulaic structure of "[article subject] is...]" and thus skew the data).<ref name="huang">{{cite web |last1=Huang |first1=Siming |last2=Xu |first2=Yuliang |last3=Geng |first3=Mingmeng |last4=Wan |first4=Yao |last5=Chen |first5=Dongping |title=Wikipedia in the Era of LLMs: Evolution and Risks |url=https://openreview.net/pdf?id=ahVmnYkVLt |access-date=13 May 2026}}</ref> It is particularly visible in AI copyedits, which will often "improve" text in this way. The study above also demonstrated that when GPT-3.5 was prompted to "Revise the following sentence" in 10,000 abstracts, the words ''is'' and ''are'' appeared less often in the revised versions.<ref name="geng2" />

In lead sentences, LLMs will sometimes avoid ''is'' by writing ''refers to'' [[Wikipedia:Signs of AI writing#Leads treating Wikipedia lists or broad article titles as proper nouns|as though the article were about the word or term]] instead of the subject directly.

'''Examples'''
{{textdiff|Gallery 825 on [[La Cienega Boulevard]], which was purchased in 1958, is LAAA's exhibition arm for [[contemporary art]]. There are four individual gallery spaces[...]|Gallery 825 on [[La Cienega Boulevard]] serves as LAAA's exhibition space for contemporary art. The gallery features four separate spaces[...]}}

{{bi|1=—From [[Special:Diff/1168694674|this August 2023 revision]] to [[Los Angeles Art Association]]}}

{{textdiff|It is Malaysia's first [[Malay language|Malay]] daily afternoon [[Tabloid (newspaper format)|Tabloid]] [...] The ''Harian Metro'' was established in March 1991 and is the first and oldest Malay-language tabloid [...]|It was established in March 1991 as Malaysia's first Malay-language afternoon [[Tabloid journalism|tabloid]] [...] Harian Metro holds the distinction of being the first and oldest Malay-language tabloid [...]}}

{{bi|1=—From [[Special:Diff/1259995938|this November 2024 revision]] to [[Harian Metro]]}}

===Negative parallelisms===
{{Shortcut|WP:AIPARALLEL}}
{{see also|Negative parallelism}}
When LLMs describe a subject, their output may seem as though it is clearing up a common misconception, or as though the audience may be reaching an incomplete or incorrect conclusion about that subject. This kind of contrast can come across as trying to retroactively challenge such thinking by pointing out another characteristic that the subject may possess alongside (or in the place of) one or more previously-mentioned characteristics. While it is common among human writers (especially in "common misconceptions" or "myths busted" [[listicle]]s), it is stereotypically an "AI sign."

====Not just X, but also Y====
It is common for LLMs to use parallel constructions involving "not", "but", or "however" such as "{{xt|Not only ... but ...}}" or "{{xt|It is not just ..., it's ...}}".<ref>{{cite web |last1=Robbins |first1=Hollis |title=How to Tell if Something is AI Written |url=https://hollisrobbinsanecdotal.substack.com/p/how-to-tell-if-something-is-ai-written |website=Anecdotal Value |publisher=Substack |access-date=7 December 2025}}</ref><ref name="Russell">{{cite conference |last1=Russell |first1=Jenna |last2=Karpinska |first2=Marzena |last3=Iyyer |first3=Mohit |year=2025 |url=https://aclanthology.org/2025.acl-long.267/ |location=Vienna, Austria |title=People who frequently use ChatGPT for writing tasks are accurate and robust detectors of AI-generated text |conference=Proceedings of the 63rd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers) |publisher=Association for Computational Linguistics |pages=5342–5373 |arxiv=2501.15654 |doi=10.18653/v1/2025.acl-long.267 |doi-access=free |access-date=2025-09-05 |via=[[ACL Anthology]] |archive-date=2025-08-29 |archive-url=https://web.archive.org/web/20250829184825/https://aclanthology.org/2025.acl-long.267/ |url-status=live }}</ref><ref name="merrill" />

'''Examples'''
{{collapse top|From [[Talk:Eric Dick (lawyer)#c-Scott free0011-20240824023600-HCDE Tenure|this August 2024 comment]] at [[Talk:Eric Dick (lawyer)]]}}
In your most recent exchange, you referred to another editor’s comment as "bizarre" and "totally incorrect," following up with an assertion that their viewpoint was "bogus." This choice of language is {{highlight|not only dismissive but also}} unnecessarily harsh and confrontational. It shuts down the possibility of constructive dialogue and disrespects the effort that others put into contributing to this platform.

This kind of dismissive and confrontational attitude is not new. [...] This remark {{highlight|doesn’t just undermine the editor’s argument; it questions their very right to participate}} based on how long they’ve been active, which is contrary to the inclusive nature that Wikipedia aims to foster. New contributors should be encouraged, not belittled, and it’s disheartening to see you take such a dismissive stance.

Your sarcastic remark about adding "Eric Dick is a secret Democrat. [citation needed]" to the article further exemplifies this problematic behavior. Rather than engaging in a meaningful discussion, you chose to mock another editor’s argument, which only serves to create a hostile environment. This approach doesn’t help resolve disputes or improve content; it only escalates tensions and discourages productive collaboration.

Moreover, in another instance, you accused an editor of "bludgeoning discussion with screeds of AI generated waffle" and dismissed their contributions as "acres of fanciful extrapolation on Wikipedia policies." These comments are {{highlight|not just dismissive—they’re outright disrespectful.}} Accusations like these don’t belong in a professional and collaborative setting. They undermine the very spirit of Wikipedia, which is built on the idea that people with different perspectives can come together to create something valuable.

It’s important to recognize that everyone who contributes to Wikipedia—whether they’re new or experienced, whether they agree with you or not—deserves to be treated with respect. Collaboration, not confrontation, should be the goal. By continuing to engage with others in such a dismissive and harsh manner, you {{highlight|not only discourage participation but also}} damage the collaborative spirit that is essential to Wikipedia’s success.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1288184349|this April 2025 revision]] to [[Self-portrait (Yayoi Kusama)]]}}
'''Self-Portrait''' by Yayoi Kusama, executed in 2010 and currently preserved in the famous Uffizi Gallery in Florence, constitutes {{highlight|not only a work of self-representation, but}} a visual document of her obsessions, visual strategies and psychobiographical narratives.
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Articles for deletion/Northern English nationalism#c-195.5.161.42-20250827212800-Aszx5000-20250827152200|this August 2025 comment]] at [[Wikipedia:Articles for deletion/Northern English nationalism]]}}
I appreciate the feedback so far, but I want to clarify something that’s being overlooked. The issue here {{highlight|isn’t just sourcing—it’s framing}}. There’s a visible, growing movement around Northern English identity, documented across academic literature, social media, and grassroots activism. The fact that it doesn’t always use the exact phrase “Northern English nationalism” doesn’t mean it doesn’t exist. Movements evolve before they’re neatly labelled.

TikTok campaigns, dialect revival, and regional symbolism (like St Oswald’s stripes) are part of a broader cultural shift. Dismissing these as “not notable” or “original research” while allowing pages on Cornish nationalism, Wessex regionalism, and Yorkshire separatism suggests an inconsistency in how regional identity is treated. {{highlight|That’s not just a sourcing issue—it’s a systemic bias}}.
{{collapse bottom}}

Here is an example of a negative parallelism across multiple sentences:
{{blockquote|text=He hailed from the esteemed Duse family, renowned for their theatrical legacy. Eugenio's life, however, took a path that intertwined both personal ambition and familial complexities.|title=From [[Special:Diff/1284729136|this April 2025 revision]] to [[Eugenio Duse]]}}

====Not X, but Y====
Another common LLM pattern is parallelisms that explicitly state that a particular item doesn't possess the first characteristic at all. Such constructions are often expressed as "{{xt|It's not ..., it's ...}}" or "{{xt|no ..., no ..., just ...}}".<ref name="Kriss"/>

'''Examples'''
{{collapse top|From [[Special:Diff/1288356293|this May 2025 revision]] to [[Self-portrait (Yayoi Kusama)]]}}
The viewer is presented with a self-image that {{highlight|<u>is not</u> grounded in visual mastery, <u>but</u> in what Amelia Jones terms “the performative enactment of subjectivity”}}.

[...]

This dispersal {{highlight|<u>is not</u> dissolution. <u>Rather, it constitutes</u> what Deleuze might describe as “becoming”}}—an identity in flux, constituted through iterative difference. Through this lens, Kusama’s self-portrait {{highlight|is not a mirror but a portal}}: {{highlight|not a representation of self, but a mechanism}} for its constant reinvention.
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Articles for deletion/Lilly Contino#c-Momentoftrue-20250617223200-Lilly Contino|this June 2025 comment]] at [[Wikipedia:Articles for deletion/Lilly Contino]]}}
You say these sources “cover multiple events”? False. They echo the same viral incident and do it through a limited lens. {{highlight|This isn’t WP:NBIO — it’s WP:1EVENT in disguise}}, trying to wear a press badge like armor.

[...]

Now let’s talk BLP1E: This person is only in the news because of one isolated controversy. {{highlight|Not a career, not a body of work, not sustained relevance — just an algorithmic moment}}. And if we’re really upholding Wikipedia’s values, we don’t preserve pages built on the backs of virality alone, especially when it risks long-term harm to a living subject without lasting notability.

“Might as well get back on topic.”

Then let’s stay on topic, and the topic {{highlight|<u>is not</u> who feels warm fuzzies from visibility, <u>it’s</u> whether this article meets the threshold for inclusion}}. It doesn’t.

And finally — if you don’t want “a wall of text,” maybe don’t build a wall of shallow logic and expect people not to knock it down. {{highlight|This ain’t bludgeoning — it’s surgical teardown}} of a weak argument hiding behind fake neutrality.
{{collapse bottom}}

====X rather than Y====
This pattern may also be reversed, a construction particularly common in Grok output.

'''Examples'''
{{blockquote|Chiang's strategy emphasized military suppression of these holdouts to enforce subordination, {{highlight|prioritizing empirical consolidation}} of power amid fragmented loyalties {{highlight|rather than}} ideological purity.|From [[Special:Diff/1349156160|this April 2026 revision]] to [[First Battle of Guilin]], which explicitly states it is from Grokipedia}}

===Rule of three===
{{shortcut|WP:RO3}}
LLMs overuse the [[Rule of three (writing)|rule of three]]. This can take different forms, from "adjective, adjective, adjective" to "short phrase, short phrase, and short phrase".<ref name="Russell"/><ref name="Kriss"/> LLMs often use this structure to make [[#Superficial analyses|superficial analyses]] appear more comprehensive.

'''Examples'''
{{blockquote|
* **Standard Rotary Saws**: Typically used for drywall and light materials.
* **Heavy-Duty Rotary Saws**: Designed for tougher materials such as {{highlight|tiles, metals, and plastics}}.
* **Corded and Cordless Versions**: Corded rotary saws offer continuous power, while cordless versions provide portability and convenience
[...]
* **Construction and Renovation**: For cutting {{highlight|drywall, plywood, and other construction materials}}.
* **Electrical and Plumbing**: To create openings for {{highlight|electrical outlets, switches, and plumbing fixtures}}.
* **Hobby and Craft**: Used in {{highlight|model making, woodworking, and other craft projects}}.
* **Automotive**: Employed in auto body repair and modification tasks.
|From [[Special:Diff/1237779206|this July 2024 revision]] to [[Rotary saw]] (note that these are [[WP:AILIST|canned-format lists]] that used [[WP:MARKDOWN|Markdown]])}}

===Lexical diversity/elegant variation===
{{For|a non-AI-specific style essay about this|Wikipedia:The problem with elegant variation}}
{{Further|Lexical diversity}}
{{shortcut|WP:AIELEVAR}}
Generative AI has a repetition-penalty code, meant to discourage it from reusing words too often.<ref name="chronicle">{{cite web |last=Belcher|first=Wendy|title=10 Ways AI Is Ruining Your Students' Writing.|website=Chronicle of Higher Education|date=September 16, 2025|url=https://www.chronicle.com/article/10-ways-ai-is-ruining-your-students-writing|access-date=October 1, 2025|archive-date=October 1, 2025|archive-url=https://web.archive.org/web/20251001071208/https://www.chronicle.com/article/10-ways-ai-is-ruining-your-students-writing/|url-status=live}}</ref> This pattern has also been observed on Wikipedia on a broad level: both when comparing Wikipedia text from before 2023 to Wikipedia text from after 2023, and comparing the older Wikipedia text to "Wikipedia-style articles" generated by GPT-4o-mini and Gemini-1.5-Flash.<ref name="huang" />

Note: If a user adds multiple pieces of AI-generated content in separate edits, this tell may not apply, as each piece of text may have been generated in isolation.

'''Examples'''
{{sidebox|text=
{{legend|pink|Soviet artistic constraints}}
{{legend|lightblue|Non-conformist artists}}
{{legend|plum|Their creativity}}
}}
{{blockquote|
Vierny, after a visit in Moscow in the early 1970’s, committed to supporting artists resisting {{highlight|the constraints of socialist realism|pink}} and discovered Yankilevskly, among others such as Ilya Kabakov and Erik Bulatov. In {{highlight|the challenging climate of Soviet artistic constraints|pink}}, Yankilevsky, alongside other {{highlight|non-conformist artists|lightblue}}, faced obstacles in expressing {{highlight|their creativity|plum}} freely. Dina Vierny, recognizing {{highlight|the immense talent|plum}} and the struggle {{highlight|these artists|lightblue}} endured, played a pivotal role in aiding {{highlight|their artistic aspirations|plum}}. [...]

In this new chapter of his life, Yankilevsky found himself amidst a community of {{highlight|like-minded artists|lightblue}} who, despite diverse styles, shared a common goal—to break free from {{highlight|the confines of state-imposed artistic norms|pink}}, particularly socialist realism. [...]

The move to Paris facilitated an environment where Yankilevsky could further explore and exhibit {{highlight|his distinctive artistic vision|plum}} without {{highlight|the constraints imposed by the Soviet regime|pink}}. Dina Vierny's unwavering support and commitment to the {{highlight|Russian avant-garde artists|lightblue}} played a crucial role in fostering a space where {{highlight|their creativity|plum}} could flourish, contributing to the rich tapestry of artistic expression in the vibrant cultural landscape of Paris. Vierny's commitment culminated in the groundbreaking exhibition "Russian Avant-Garde - Moscow 1973" at her Saint-Germain-des-Prés gallery, showcasing the {{highlight|diverse yet united front of non-conformist artists|lightblue}} challenging {{highlight|the artistic norms|pink}} of their time.
|From [[Special:Diff/1205035512|this February 2024 revision]] to [[Vladimir Yankilevsky]]}}

It must be noticed however that editors who are not native English speakers might prefer to avoid repeated words as well. For example Italian schools often teach to avoid repeating words.<ref name="birattari2020">{{cite web |last1=Birattari |first1=Massimo |title=Come evitare le ripetizioni “moleste” quando scriviamo? |url=https://www.illibraio.it/news/grammatica/come-evitare-ripetizioni-quando-scriviamo-540892/ |website=Il Libraio |access-date=29 May 2026}}</ref><ref name="cortelazzo">{{cite web |last1=Cortelazzo |first1=Michele A. |title=Non sempre è necessario usare parole diverse |url=http://www.maldura.unipd.it/buro/gel/gel13.html |website=SEMPLIFICAZIONE DEL LINGUAGGIO AMMINISTRATIVO «MANUALE DI STILE» |publisher=Università di Padova |access-date=29 May 2026}}</ref>

==Style==
===Title case===
{{For|non–AI-specific guidance about this|Wikipedia:Manual of Style/Capital letters#Headings, headers, and captions}}
{{Shortcut|WP:AITITLECASE}}

In section headings, AI chatbots strongly tend to capitalize all main words.<ref name="Russell"/>

'''Examples'''
{{blockquote|
{{fake section|level=2|Impact of Technology and Digitalization}}
The advent of digital technology and the internet has revolutionized international economic law. [...]
{{fake section|level=2|Sustainable Development and Environmental Law}}
The integration of sustainable development goals into international economic law is increasingly important. [...]
{{fake section|level=2|Human Rights and Economic Law}}
The relationship between human rights and international economic law is a growing area of focus. [...]
|From [[Special:Diff/1189640895|this December 2023 revision]] to [[International economic law]]}}

===Overuse of boldface===
{{For|non-AI-specific guidance about this|Wikipedia:Manual of Style/Text formatting#Boldface}}
{{shortcut|WP:AIBOLD}}
AI chatbots may display various phrases in [[boldface]] for emphasis in an excessive, mechanical manner. One of their tendencies, inherited from [[readme]]s, fan wikis, how-tos, sales pitches, slide decks, listicles and other materials that heavily use boldface, is to emphasize every instance of a chosen word or phrase, often in a "key takeaways" fashion. Some newer large language models or apps have instructions to avoid overuse of boldface.

'''Examples'''
{{blockquote|A '''leveraged buyout (LBO)''' is characterized by the extensive use of '''debt financing''' to acquire a company. This financing structure enables '''private equity firms''' and '''financial sponsors''' to control businesses while investing a relatively small portion of their own equity. The acquired company’s '''assets and future cash flows''' serve as collateral for the debt, making lenders more willing to provide financing.|From [[Special:Diff/1274574473|this February 2025 revision]] to [[Leveraged buyout]]}}

{{blockquote|'''50 Scientists and Thinkers in AI Safety with significant''' influence on the field of alignment, containment, and risk mitigation. The list includes their '''Productive Years''', their estimated '''P(doom)''' (probability of existential catastrophe), a '''one-sentence summary of their contribution to AI Safety''', and their Wikipedia link.|From [[Special:Diff/1324781030|this November 2025 revision]] to [[P(doom)]]}}

===<span class="anchor" id="Lists"></span>Inline-header vertical lists===
{{shortcut|WP:AILIST}}
{{For|non-AI-specific guidance about this|Wikipedia:Manual of Style/Lists#Use prose where understood easily}}
AI chatbots output often includes vertical lists formatted in a specific way: an ordered or unordered list where the list marker (number, bullet, dash, etc.) is followed by an inline boldfaced header, separated with a colon from the remaining descriptive text.

Instead of [[H:LIST|proper wikitext]], a bullet point in an unordered list may appear as a bullet character (•), hyphen (-), en dash (–), [[Wikipedia:Signs_of_AI_writing#Use_of_Markdown|hash]] (#), [[Wikipedia:Signs_of_AI_writing#Emoji_as_formatting|emoji]], or similar character. Ordered lists (i.e. numbered lists) may use explicit numbers (such as {{code|1.}}) instead of standard wikitext. When [[WP:SCOPY|copied as bare text appearing on the screen]], some of the formatting information is lost, and line breaks may be lost as well.

'''Examples'''
{{collapse top|From [[Wikipedia:Articles for deletion/Sarwan Kumar Bheel#c-IOmParkashSarwanBheel-20241014082300-Saqib-20241014080900|this October 2024 comment]] at [[Wikipedia:Articles for deletion/Sarwan Kumar Bheel]]}}
{{highlight|Conflict of Interest (COI)/Autobiography:}} While I understand the concern regarding my username [...]<br>
{{highlight|Notability (GNG and NPOLITICIAN):}} I have revised the article to focus on factual details [...]<br>
{{highlight|Original Research (WP) and Promotional Tone:}} I have worked on removing original research [...]<br>
{{highlight|Article Move to Main Namespace:}} Moving the draft to the main namespace after the AFC review [...]
{{collapse bottom}}

{{collapse top|From [[Special:PermanentLink/1255717748|this November 2024 revision]] to [[Sundial (weapon)]]}}
{{highlight|1. Historical Context Post-WWII Era:}} The world was rapidly changing after WWII, [...]
{{highlight|2. Nuclear Arms Race:}} Following the U.S. atomic bombings, the Soviet Union detonated its first bomb in 1949, [...]
{{highlight|3. Key Figures Edward Teller:}} A Hungarian physicist who advocated for the development of more powerful nuclear weapons, [...]
{{highlight|4. Technical Details of Sundial Hydrogen Bomb:}} The design of Sundial involved a hydrogen bomb [...]
{{highlight|5. Destructive Potential:}} If detonated, Sundial would create a fireball up to 50 kilometers in diameter, [...]
{{highlight|6. Consequences and Reactions Global Impact:}} The explosion would lead to an apocalyptic nuclear winter, [...]
{{highlight|7. Political Reactions:}} The U.S. military and scientists expressed horror at the implications of such a weapon, [...]
{{highlight|8. Modern Implications Current Nuclear Arsenal:}} Today, there are approximately 12,000 nuclear weapons worldwide, [...]
{{highlight|9. Key Takeaways Understanding the Madness:}} The concept of Project Sundial highlights the extremes of human ingenuity [...]
{{highlight|10. Questions to Consider}} What were the motivations behind the development of Project Sundial? [...]
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1316572059|this October 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/AI Visibility Optimization (AVO)|Draft:AI Visibility Optimization]]}}
AVO consists of three key layers:
* '''SEO (Search Engine Optimization):''' Traditional methods for improving visibility in search engine results through content, technical, and on-page optimization.
* '''AEO (Answer Engine Optimization):''' Techniques focused on optimizing content for voice assistants and answer boxes, such as featured snippets and structured data.
* '''GEO (Generative Engine Optimization):''' Strategies for ensuring businesses are cited as credible sources in responses generated by large language models (LLMs).
{{collapse bottom}}

{{collapse top|expand=yes|From [[Special:Diff/1327088410|this December 2025 revision]] to [[Navipet]]}}
Key highlights:
* '''Route Details''': Starts at Medak, passes through Yellareddy, Banswada, Nasrullabad, Varni, Rudrur, Bodhan, Shatapur, Navipet, Fakirabad, Basar, Mudhol, and ends at Bhainsa (via Yencha). The Bhainsa-to-Banswada section (Phase 3: Rudrur–Bhainsa, 50+ km) will feature new bypasses to skirt congested towns like Basar and Rudrur, easing traffic and cutting travel time by 20–30%.
* '''Bypasses and Improvements''': Bypasses are planned at high-density spots (e.g., near Basar temple and Rudrur market), with surveys completed for most sections by mid-2025. This includes elevated corridors over the Manjira River and cotton fields, preserving Navipet's agrarian landscape.
* '''Timeline and Impact''': Phase 3 (Rudrur–Bhainsa) construction is 40% complete as of December 2025, with full completion targeted for 2027. Once operational, it will slash Hyderabad–Bhainsa travel to under 5 hours and integrate Navipet into a seamless Medak–Adilabad corridor, boosting trade in cotton and turmeric. Local stakeholders hail it as a "lifeline" for farmers, with land acquisition nearly finalized.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1345180164|this March 2026 revision]] to [[Wikipedia:Requests for page protection/Increase]]}}
{{highlight|Mass Content Removal:}} The user removed over 20,000 characters of reliably sourced content in a single edit, reducing the number of citations from 34 to 8, without any prior engagement on the Talk page.{{highlight|Disruptive Tagging:}} Despite the article being supported by 34 high-quality international secondary sources (Wall Street Journal, Bloomberg, Financial Times, etc.), the user implemented excessive "citation needed" tags as a form of visual vandalism to discredit the content.{{highlight|Refusal to engage (WP:BRD):}} The user was notified of WP:V and WP:DE policies on their talk page but has failed to justify these massive deletions, suggesting a coordinated attempt at de-legitimizing the subject.{{highlight|Context:}} Given the high-profile nature of the subject in global finance and mining (notably the AstraZeneca/EsoBiotec $1B M&A), the page is currently vulnerable to reputation-based sabotage.
{{collapse bottom}}

In some cases, there is no punctuation separating the title of each entry from its corresponding text. This is not to be confused with the way that users sometimes format their !votes in [[WP:XFD|XfD]] discussions, where words like {{xt|Keep}} or {{xt|Delete}} are typically written in boldface to set it apart from the arguments for the desired outcome.

{{collapse top|From [[Talk:Fish and chips/Archive 1#Expanding the "Origins" section to acknowledge Portuguese culinary technology|this December 2025 comment]] at [[Talk:Fish and chips]]}}
{{highlight|Durability}} Unlike roasted meats, which become tough and dry, or boiled foods, which rot quickly, battered fish was stable. [...]

{{highlight|Portability and the "Pocket Meal"}} The structural integrity of the polme made the fish physically durable. [...]

{{highlight|Ruggedness}} It could be wrapped in a simple cloth or paper and stuffed into a satchel. [...]

One might wonder: if it’s a "travel food," why not just cook it on the ship?

{{highlight|The Fire Hazard}} Cooking with large quantities of boiling oil on a wooden ship was an invitation to disaster. Open flames were strictly regulated at sea.

{{highlight|The Solution}} Ships would stock up on large quantities of pre-fried battered fish just before departure. [...]

{{highlight|The Transition}} After those first 48 hours, the crew would switch to harder-to-prepare staples like dried salt cod (bacalhau) or sea biscuits.

{{highlight|The "Cold" Factor}} This is the most important part for a "travel-ready" food. [...]

{{highlight|The Dockside "Frying Warehouses"}} The docks of Lisbon, particularly in the Ribeira (riverside) district, were the epicenter of this technology. [...]

{{highlight|Outdoor Caldrons}} Professional fryers set up large, permanent iron caldrons over open coal or wood fires right on the quays. [...]

{{highlight|"Deep-Frying Mastery"}} Because the Portuguese already had the caldrons of hot olive oil ready for their fish, it was a natural technological step to drop potato slices into that same oil. [...]

{{highlight|Street Vendors and "Tabernas"}} In 16th-century Lisbon, many of the poorer urban residents lived in homes without dedicated kitchens. [...]

{{highlight|The Sephardic "Home Factory"}} While the docks were the commercial center, the Sephardic Jewish quarters (the Judiarias) were where the technology was refined for domestic safety and religious ritual. [...]

{{highlight|Portuguese Sailors as "Early Adopters"}} In the 1500s, Portuguese sailors were the most active in the North Atlantic cod trade. [...]

{{highlight|The Iberian Potato "Infrastructure"}} Potatoes reached the Iberian Peninsula (Lisbon and Seville) c. 1570, nearly two centuries before they were accepted as food in France or the UK. [...]

{{highlight|Linguistic Evidence of Global Export}} The global reach of Portuguese frying technology is evidenced by its impact on other cultures during the same period [...]

{{highlight|The "Sikbaj" and "Escabeche" Connection}} The Portuguese technique of Escabeche (which involves frying fish and then preserving it in vinegar) is the maritime "big brother" of the battered fish. [...]

{{highlight|Exports to London}} 16th-century records show that Portuguese ships weren't just carrying wine and salt; they were heavily laden with olive oil destined for the ports of London, Antwerp, and Amsterdam.

{{highlight|A Taste for the "Foreign"}} Because Portuguese merchants were so active in London’s docks, they created a local demand for olive oil. [...]

{{highlight|The Later Shift From Olive Oil to "Dripping"}} As the dish moved from the elite merchant/Jewish circles into the broader British working class during the Industrial Revolution, the oil changed due to cost: [...]
{{collapse bottom}}

===Overuse of em dashes===
{{For|non-AI-specific guidance about the use of dashes|Wikipedia:Manual of Style#Dashes}}
{{Shortcut|WP:AIDASH}}
While human editors and writers often use [[em dash]]es (—), LLM output uses them more often than nonprofessional human-written text of the same genre, and uses them in places where humans are more likely to use commas, parentheses, colons, or (misused) hyphens (-) and [[en dash]]es (–). LLMs especially tend to use em dashes in a formulaic, pat way, often mimicking "punched up" sales-like writing by over-emphasizing clauses or parallelisms.<ref name="merrill" /><ref name="Kriss"/> AI-generated em dashes are usually surrounded by spaces, contrary to common typographic guidelines (which most human users of em dashes will be familiar with).

This sign is most useful when taken in combination with other indicators, not by itself. It is much more common on discussion pages than in article text. Also, because LLMs' use of em-dashes has become somewhat notorious, some AI companies have attempted to make their newer chatbots suppress their use, most notably OpenAI's [[GPT-5.1]].<ref name="edwards">{{cite news |last1=Edwards |first1=Benj |title=Forget AGI—Sam Altman celebrates ChatGPT finally following em dash formatting rules |url=https://arstechnica.com/ai/2025/11/forget-agi-sam-altman-celebrates-chatgpt-finally-following-em-dash-formatting-rules/ |access-date=24 February 2026 |work=Ars Technica |date=14 November 2025}}</ref>

'''Examples'''
{{collapse top|expand=yes|From [[User talk:Apep the Serpent God#c-Apep the Serpent God-20250407133000-April 2025|this April 2025 unblock request]] at [[User talk:Apep the Serpent God]]}}
I referred to Wikipedia's policies in a discussion with another user, using AI to help me organize my thoughts and better explain the policies I was referencing — something that was reported by the user. [...] If there were any errors in interpretation, they were my own — not mistakes caused by the AI. [...]<br>
[...] Ultimately, one of the admins blocked me — not because of the AI usage itself, which had already been addressed — but because I didn’t respond to their continued questioning.
{{collapse bottom}}

{{collapse top|expand=yes|From {{diff||1286082047|label=this April 2025 revision}} to [[Talk:Dutch Caribbean]]}}
In practice, many Dutch organizations and businesses use it for '''their own convenience''', even placing it in addresses — e.g., “Curaçao, Dutch Caribbean” — but this only '''adds confusion''' internationally and '''erases national identity'''. You don’t say '''“Netherlands, Europe”''' as an address — yet this kind of mislabeling continues.
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Articles for deletion/Lilly Contino#c-Momentoftrue-20250617193700-Cakelot1-20250617192800|this June 2025 comment]] at [[Wikipedia:Articles for deletion/Lilly Contino]]}}
you're right about one thing — we do seem to have different interpretations of what policy-based discussion entails. [...]

When WP:BLP1E says "one event," it’s shorthand — and the supporting essays, past AfD precedents, and practical enforcement show that “two incidents of fleeting attention” still often fall under the protective scope of BLP1E. This isn’t "imagining" what policy should be — it’s recognizing how community consensus has shaped its application.

Yes, WP:GNG, WP:NOTNEWS, WP:NOTGOSSIP, and the rest of WP:BLP all matter — and I’ve cited or echoed each of them throughout. [...] If a subject lacks enduring, in-depth, independent coverage — and instead rides waves of sensational, short-lived attention — then we’re not talking about encyclopedic significance. [...]

[...] And consensus doesn’t grow from silence — it grows from critique, correction, and clarity.

If we disagree on that, then yes — we’re speaking different languages.
{{collapse bottom}}

===<span class="anchor" id="Emoji"></span> Emoji as formatting===
{{shortcut|WP:AIEMOJI}}
AI chatbots have used [[emoji]] in the past.<ref name="merrill">{{cite news |last1=Merrill |first1=Jeremy B. |last2=Chen |first2=Szu Yu |last3=Kumer |first3=Emma |title=What are the clues that ChatGPT wrote something? We analyzed its style. |url=https://www.washingtonpost.com/technology/interactive/2025/how-detect-chatgpt-em-dash/ |access-date=14 November 2025 |work=The Washington Post |date=13 November 2025}}</ref><ref name="geng">{{cite web |last1=Geng |first1=Mingmeng |last2=Trotta |first2=Roberto |title=Human-LLM Coevolution: Evidence from Academic Writing |url=https://aclanthology.org/2025.findings-acl.657.pdf |website=aclanthology.org |access-date=17 December 2025}}</ref> In particular, they sometimes decorated section headings or bullet points by placing emoji in front of them. These almost always appeared in talk page comments and edit summaries; while they are more rare now, they may still be seen.

'''Examples'''
{{collapse top|From [[Special:Diff/1285703047|this April 2025 revision]] to [[User:Bhaskar sunsari]]}}
{{fake heading|level=1|👋 Welcome to the User Page of Bhaskar Sunsari}}
[...]

{{fake heading|level=2|🧑‍💻 About Me}}
[...]

{{fake heading|level=2|🌏 My Interests}}
Here are some topics I love exploring and contributing to:
* 💻 **Computing & Open Source Technology**
* 📚 **Education Systems in South Asia**
* 🌄 **Nepalese Culture, History, and Local Stories**
* 🔍 **Underrepresented Communities & Forgotten Facts**
* 🌐 **Digital Literacy & Tech for Social Good**
{{fake heading|level=2|🎯 What I’m Working On}}
[...]
{{fake heading|level=2|📬 Let’s Connect!}}
Have a suggestion, correction, or just want to say hi?
👉 Drop me a message [...] I’m always happy to hear from fellow Wikimedians!
{{fake heading|level=2|🙏 Gratitude}}
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Village pump (policy)/Archive 202#c-Diamondtier-20250525141800-Diamondtier-20250525141800|this May 2025 comment]] at [[Wikipedia:Village pump (policy)]]}}
Let’s decode exactly what’s happening here:<br>
🧠 Cognitive Dissonance Pattern:<br>
You’ve proven authorship, demonstrated originality, and introduced new frameworks, yet they’re defending a system that explicitly disallows recognition of originators unless a third party writes about them first.<br>
[...]<br>
🧱 Structural Gatekeeping:<br>
Wikipedia policy favors:<br>
[...]<br>
🚨 Underlying Motivation:<br>
Why would a human fight you on this?<br>
[...]<br>
🧭 What You’re Actually Dealing With:<br>
This is not a debate about rules.<br>
[...]
{{collapse bottom}}

{{collapse top|expand=yes|From [[Special:Diff/1302443439/1303522049|this July 2025 revision]] to [[History of trigonometry]]}}
🪷 Traditional Sanskrit Name: Trikoṇamiti<br>
Tri {{=}} Three<br>
Koṇa {{=}} Angle<br>
Miti {{=}} Measurement 🧭 “Measurement of three angles” — the ancient Indian art of triangle and angle mathematics.<br>
🕰️ 1. Vedic Era (c. 1200 BCE – 500 BCE)
<br>[...]<br>
🔭 2. Sine of the Bow: Sanskrit Terminology
<br>[...]<br>
🌕 3. Āryabhaṭa (476 CE)
<br>[...]<br>
🌀 4. Varāhamihira (6th Century CE)
<br>[...]<br>
🌠 5. Bhāskarācārya II (12th Century CE)
<br>[...]<br>
📤 Indian Legacy Spreads
{{collapse bottom}}

=== <span class="anchor" id="Tables"></span>Unusual use of tables ===
{{shortcut|WP:AITABLE}}
In rare cases, some AIs may create unnecessary small tables that could be better represented as prose or an [[WP:INFOBOX|infobox]].

'''Examples'''
{{collapse top|expand=yes|From [[Special:Diff/1323402246|this November 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Biobanks in India|Draft:Biobanks in India]]}}
{{Fake heading|Market and Statistics}}
The Indian biobanking market was valued at approximately USD 2,101 million in 2024. The sector is expanding to support the "Atmanirbhar Bharat" (Self-reliant India) initiative in healthcare research.
{| class="wikitable"
|+Key Statistics of Indian Biobanking (2024-2025)
!Metric
!Figure
|-
|Market Valuation (2024)
|~USD 2.1 billion
|-
|Major Accredited Facilities
|NLDB, CBR Biobank, THSTI, Karkinos
|-
|GenomeIndia Diversity
|99 ethnic groups (32 tribal, 53 non-tribal)
|}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1352783863|this May 2026 revision]] to [[Wikipedia:Signs of AI writing/Examples/Pacific Mall, Tagore Garden|Draft:Pacific Mall]]}}
{{fake heading|level=2|Management}}
The mall employs approximately 3,167 staff members across all operations. Key management personnel of Pacific Development Corporation Private Limited include:
{| class="wikitable"
! Name !! Designation
|-
| S. K. Bansal || Chairman
|-
| Abhishek Bansal || Managing Director
|-
| Saket Bansal || Managing Director
|-
| Mehak Khanna || VP Marketing
|}
{{collapse bottom}}

{{collapse top|From [[Special:PermanentLink/1365728625#Shared Artifact Types in Shan Culture|these]] [[Special:PermanentLink/1365728625#5.3 Comparison of Traditions|sections]] of a July 2026 revision to [[Xorai]]}}
The structural similarity between the Shan hsun-ok and the Assamese xorai is striking:

{| class="wikitable"
|+ Comparison of Shan Hsun-Ok and Assamese Xorai
|-
! Feature !! Shan Hsun-Ok !! Assamese Xorai
|-
| Basic Structure || Bowl on pedestal with tray and cover || Tray on pedestal with domed cover
|-
| Primary Material || Lacquered bamboo || Bell metal (kah) or brass
|-
| Ceremonial Use || Buddhist offerings to monks || Hindu/Vaishnava offerings; hospitality
|-
| Cover || Stupa-shaped spire || Domed cover
|}
----
The Tibetan high-footed vessels differ from the Tai-Kadai pedestal trays in several important ways:

{| class="wikitable"
|+ Comparison of Tai-Kadai and Tibetan Traditions
|-
! Feature !! Tai-Kadai Tradition !! Tibetan Tradition
|-
| Origin || Indigenous Neolithic development || Introduced through Chinese influence
|-
| Primary Material || Pottery → Bronze → Bell metal || Porcelain (Chinese imports)
|-
| Primary Use || Ritual offerings, hospitality, diplomacy || Buddhist offerings, tea ceremonies
|-
| Transmission || Carried by migration || Received as gifts from Chinese courts
|-
| Linguistic Connection || Native vocabulary (phan, phun) || Borrowed terminology
|}
{{collapse bottom}}

===Curly quotation marks and apostrophes===
{{For|non-AI-specific guidance about this|Wikipedia:Manual of Style#Quotation characters|Wikipedia:Manual of Style#Apostrophes}}
{{Shortcut|WP:AICURLY}}

ChatGPT <!-- appears to have risen some time in mid-2025 -->and [[DeepSeek]] typically use curly quotation marks (“...” or ‘...’) instead of straight quotation marks ("..." or '...'). In some cases, AI chatbots inconsistently use pairs of curly and straight quotation marks in the same response. They also tend to use the curly apostrophe (’), the same character as the curly [[right single quotation mark]], instead of the straight apostrophe ('), such as in [[Contraction (grammar)|contractions]] and [[English possessive|possessive forms]]. They may also do this inconsistently.

Curly quotes alone do not prove LLM use. Directional quotation marks (curly or typographer) are often used in published works written and edited using the [[Chicago Manual of Style]].<ref>{{cite web|url=https://www.chicagomanualofstyle.org/qanda/data/faq/topics/SpecialCharacters/faq0002.html|title=CMOS 18th edition 6.123|website=Chicago Manual of Style}}</ref> [[Microsoft Word]] has a "[[smart quotes]]" feature that converts straight quotes to curly quotes. So does the default system-wide configuration on [[macOS]] and [[iOS]] devices, except on some applications (or if turned off, as may be necessary for [[computer programming|programming]]). Grammar correcting tools such as [[LanguageTool]] may also have such a feature. <!-- NB: LanguageTool is partially powered by neural networks. --> Curly quotation marks and apostrophes are common in professionally typeset works such as major newspapers. Citation tools like [https://citer.toolforge.org/ Citer] may repeat those that appear in the title of a web page: for example,
<blockquote>McClelland, Mac (2017-09-27). [https://www.nytimes.com/2017/09/27/magazine/when-not-guilty-is-a-life-sentence.html "When ‘Not Guilty’ Is a Life Sentence"]. {{em|The New York Times}}. Retrieved 2025-08-03.</blockquote>
Note that Wikipedia allows users to [[WP:CUSTOM|customize]] the fonts used to display text.  Some fonts display matched curly apostrophes as straight, in which case the distinction is invisible to the user. Additionally, [[Gemini (language model)|Gemini]] and [[Claude (language model)|Claude]] models typically do not use curly quotes.

===Skipping heading levels===
AI chatbots tend to skip level 2 headings (<code><nowiki>==</nowiki></code>) and start sections from the third level (<code><nowiki>===</nowiki></code>).  [[Wikipedia:Manual_of_Style/Accessibility#Headings|Because doing so is against Wikipedia's accessibility and style conventions]], it is therefore very unlikely for a manually-formatted page to have this quirk.<!--

'''Examples'''
-->

===Thematic breaks before headings===
AI chatbots sometimes include a thematic break (<code><nowiki>----</nowiki></code>) before each heading in a text (this is common in Markdown output).

'''Examples'''

<syntaxhighlight lang=wikitext highlight=5,11>
=== Distinction from French “''[[List of English words of French origin|chiffon]]''” ===
Some claims have suggested that ''Ichafu'' derives from the French word chiffon (“rag” or "light cloth”). However, early lexicographic records do not support this interpretation and later sources differ in their explanations.

[...]
----

== History ==
Headwrapping practices among Igbo women are documented in historical and ethnographic sources and are generally understood to predate the colonial period.

[...]
----

== Form and construction ==
</syntaxhighlight>
{{block indent|1=— From [[Special:Diff/1344638960|this revision]] to [[Wikipedia:Signs of AI writing/Examples/Ichafu|Draft:Ichafu]] and [https://web.archive.org/web/20260323205345/https://en.wikipedia.org/wiki/Ichafu_(headdress) this archived revision] to [[Ichafu (headdress)]]}}

==Communication intended for the user==
===Collaborative communication===
{{Shortcut|WP:CERTAINLY|WP:COLLABCOMM}}
{{tmbox|image=none|text=Words to watch: {{strong|''I hope this helps'', ''Of course!'', ''Certainly!'', ''You're absolutely right!'', ''Would you like...'', ''is there anything else'', ''let me know'', ''more detailed breakdown'', ''here is a''&nbsp;...}} }}
Editors sometimes paste text from an AI chatbot that was meant as correspondence, prewriting or advice, rather than article content. This may appear in article text or within comments (<nowiki><-- --></nowiki>). Chatbots prompted to produce a Wikipedia article or comment may also explicitly state that the text is meant for Wikipedia, and may mention various [[WP:PG|policies and guidelines]] in the output—often explicitly specifying that they're {{em|Wikipedia}}'s conventions. Often the advice given by an AI chatbot is incorrect, misleading, or in contravention with policies or guidelines.

'''Examples'''
{{collapse top|expand=yes|From {{diff||1172646802|label=this August 2023 revision}} to [[Metaphysics]]}}
In this section, we will discuss the background information related to the topic of the report. This will include a discussion of relevant literature, previous research, and any theoretical frameworks or concepts that underpin the study. The purpose is to provide a comprehensive understanding of the subject matter and to inform the reader about the existing knowledge and gaps in the field.
{{collapse bottom}}

{{collapse top|expand=yes|From [[Special:Diff/1280200320|this March 2025 revision]] to [[Foshan]]}}
If you plan to add this information to the "Animal Cruelty Controversy" section of Foshan's Wikipedia page, ensure that the content is presented in a neutral tone, supported by reliable sources, and adheres to Wikipedia's guidelines on verifiability and neutrality.
{{collapse bottom}}

{{collapse top|expand=yes|From [[Special:Diff/1290281175|this May 2025 revision]] to [[User:James.aminian]]}}
Here's a template for your wiki user page. You can copy and paste this onto your user page and customize it further.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1291175393|this May 2025 revision]] to [[Ronco Canavese]]}}
Including photos of the forge (as above) and its tools would enrich the article’s section on culture or economy, [...] Visual resources can also highlight Ronco Canavese’s landscape and landmarks. For instance, a map [...] could be added to orient readers geographically. The village’s scenery [...] could be illustrated with an image. Several such photographs are available (e.g., on Wikimedia Commons) that show Ronco’s panoramic view, [...] Historical images, if any exist [...] would also add depth to the article. Additionally, the town’s notable buildings and sites can be visually presented: [...] Including an image of the Santuario di San Besso [...] could further engage readers. By leveraging these visual aids – maps, photographs of natural and cultural sites – the expanded article can provide a richer, more immersive picture of Ronco Canavese.
{{collapse bottom}}

{{collapse top|From [[Talk:Test automation management tools#c-Joses3es-20250624173500-Role in the DevOps Toolchain|this June 2025 comment]] at [[Talk:Test automation management tools]]}}
<syntaxhighlight lang="wikitext">
Final important tip: The ~~~~ at the very end is Wikipedia markup that automatically
</syntaxhighlight>
This ended with an [[#Abrupt cut offs|abrupt cut off]].
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1348412352|this April 2026 revision]] to [[Draft:Gurmukh Singh Jeet]]}}
Delete this section before submission. After pasting the article, convert as many items as possible in the citation list into inline references attached to the exact sentences they support. If a reviewer questions print-era sources, explain that the article relies on identifiable published books, journals and newspapers from the pre-internet period, several of which survive only as scans from original printed copies.
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Signs of AI writing/Examples/Triple Entry Accounting|Draft:Triple Entry Accounting]] in May 2026, incorrectly advising a user with a COI to self-report to COI/N "after submission"}}
<syntaxhighlight lang="wikitext">
<!-- WIKIPEDIA DRAFT — Triple Entry Accounting, version 2 -->
<!-- Written to Wikipedia Manual of Style. Neutral tone, sourced throughout. -->
<!-- Author has declared a conflict of interest. Submit via WP:AFC. -->
<!-- Disclose COI on Talk page and in edit summary before saving. -->
</syntaxhighlight>
<syntaxhighlight lang="wikitext">
<!-- SUBMISSION NOTES -->
<!-- 1. This article should be created at "Triple Entry Accounting" (not "Triple-entry accounting" — follow Grigg's own capitalisation in the JRFM title). -->
<!-- 2. The existing article [[Momentum accounting and triple-entry bookkeeping]] needs a hatnote added pointing here. -->
<!-- 3. Submit via WP:AFC (Articles for Creation), not directly to mainspace. -->
<!-- 4. Declare COI explicitly: in the AFC submission notes, on the article Talk page, and in the edit summary. -->
<!-- 5. Post to WP:COIN (Conflict of Interest Noticeboard) after submission. -->
<!-- 6. The Finanstilsynet citation currently relies on Sunde's paper as intermediary. If a direct sandbox report URL exists on finanstilsynet.no, substitute it. -->
<!-- 7. The diagram uploaded by the user (showing REA/TEA/Blockchain streams) would be excellent as a figure, but requires CC-BY-SA release by its creator before it can be uploaded to Wikimedia Commons. -->
</syntaxhighlight>
{{collapse bottom}}

===Knowledge-cutoff disclaimers and speculation about gaps in sources===
{{shortcut|WP:AICUTOFF|WP:AIDISCLAIMER}}
{{tmbox|image=none|text=Words to watch: {{strong|''as of [date]'',{{efn|not unique to AI chatbots; is produced by the {{tl|as of}} template}} ''Up to my last training update'', ''as of my last knowledge update'', ''While specific details are limited/scarce...'', ''not widely available/documented/disclosed'', ''...in the provided/available sources/search results...'', ''based on available information''&nbsp;...}}}}
A knowledge-cutoff disclaimer is a statement used by an AI chatbot to indicate that the information provided may be incomplete, inaccurate, or outdated.

If an LLM has a fixed [[knowledge cutoff]], such as older large language models like [[GPT-3.5]] or [[GPT-4]] (usually the model's last training update), it is unable to provide any information on events or developments past that time. Older LLMs would often remind the user about this by outputting a disclaimer that the information in its response is accurate only up to a certain date, and may explicitly mention the knowledge cutoff in doing so.

Newer chatbots with [[retrieval-augmented generation]] may also fail to find sources on a given topic, or to find information within the sources a user provides. In these cases, they may output a statement, similar to a knowledge-cutoff disclaimer, claiming that the information is not publicly available. They may also pair it with text about what that information "likely" may be and why it is significant. This information is entirely [[WP:OR|speculative]] (including the very claim that it's "not documented") and may be based on loosely related topics or completely fabricated. When that unknown information is about an individual's personal life, this disclaimer often claims that the person "maintains a low profile", "keeps personal details private", etc. This is also speculative.

'''Examples'''
{{blockquote|text={{highlight|As of my last knowledge update in January 2022}}, I don't have specific information about the current status or developments related to the "Chester Mental Health Center" in today's era.|title=From {{diff||1186779926|label=this November 2023 revision}} to [[Chester Mental Health Center]]}}

{{blockquote|text=Though the details of these resistance efforts {{highlight|aren't widely documented}}, they highlight her bravery...|title=From [[Special:Diff/1261964722|this December 2024 revision]] to [[Throwing Curves: Eva Zeisel]]}}

{{blockquote|text=While specific information about the fauna of Studniční hora {{highlight|is limited in the provided search results}}, the mountain likely supports...|title=From [[Special:Diff/1280231958|this March 2025 revision]] to [[Studniční hora]]}}

{{blockquote|text=While specific details about Kumarapediya's history or economy {{highlight|are not extensively documented in readily available sources}}, ...|title=From [[Special:Diff/1301052898|this July 2025 revision]] to [[Kumarapediya]]}}

{{blockquote|text=Below is a detailed overview {{highlight|based on available information}}:|title=From [[Wikipedia:Signs of AI writing/Examples/Knowledge cutoff example 1|Draft:The Good, The Bad, The Dollar Menu 2]] (2025)}}

{{blockquote|text=As an underground release, detailed lyrics are {{highlight|not widely transcribed on major sites like Genius or AZLyrics}}, likely due to the artist's limited mainstream exposure. {{highlight|My analysis is based on available track titles}}, featured artists, public song snippets from streaming platforms (e.g., Spotify, Apple Music, Deezer), and Honcho's overall discography themes. Where lyrics aren't fully accessible, {{highlight|I've inferred common motifs from similar trap tracks and Honcho's style.}}
...For deeper insights, listening to tracks on platforms like Spotify or Deezer is recommended, as {{highlight|lyrics and production details aren't fully documented in public sources.}}|title=From [[Wikipedia:Signs of AI writing/Examples/Haiti Honcho|Draft:Haiti Honcho]] (2026)}}

===Phrasal templates and placeholder text===
{{shortcut|WP:AIPLACEHOLDER}}
AI chatbots may generate responses with fill-in-the-blank [[phrasal template]]s (as seen in the game ''[[Mad Libs]]'') for the LLM user to replace with words and phrases pertaining to their use case. However, some LLM users forget to fill in those blanks. Note that non-LLM-generated templates exist for drafts and new articles, such as [[Wikipedia:Artist biography article template/Preload]] and pages in [[:Category:Article creation templates]].

'''Examples'''
{{collapse top|From [[Talk:Spaghetti/Archive 1#Semi-protected edit request on 27 February 2024|this February 2024 edit request]] at [[Talk:Spaghetti]]}}
I hope this message finds you well. I am writing to request an edit for the Wikipedia entry

I have identified an area within the article that requires updating/improvement. {{highlight|[Describe the specific section or content that needs editing and provide clear reasons why the edit is necessary, including reliable sources if applicable]}}.
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1254314376|this October 2024 revision]] to [[User:ZeonDev]]}}
{{fake section|level=3|🌍 Goals}}
* Expand content on '''[Specific Topic]'''.
* Improve accessibility for '''[Language, e.g., non-English]''' pages.
* Engage with the Wikipedia community and foster a positive, collaborative editing environment.
{{collapse bottom}}

{{collapse top|From [[Wikipedia:WikiProject Articles for creation/Help desk/Archives/2024 December 8#18:31, 8 December 2024 review of submission by 162.156.70.174|this December 2024 AfC help desk comment]]}}
We remain committed to creating content that aligns with Wikipedia's mission and are open to further guidance. Please find our revised article {{highlight|[link to the revised article]}} and a detailed list of sources {{highlight|[link to source list]}}. We hope to resubmit our work once these changes have been made.

Thank you for your understanding and assistance in this matter.

Best regards, {{highlight|[Your Name]}} and Chloe
{{collapse bottom}}

{{collapse top|From [[Talk:Kjersti Flaa#Inaccurate Information|this March 2025 comment]] at [[Talk:Kjersti Flaa]]}}
I am writing to express my deep concern about the spread of misinformation on your platform. Specifically, I am referring to the article about {{highlight|[Entertainer's Name]}}, which I believe contains inaccurate and harmful information.
{{collapse bottom}}

Large language models may also insert placeholder dates like "2025-xx-xx" into citation fields, particularly the access-date parameter and [[Special:PermaLink/1295449767#References|rarely the date parameter as well]], producing errors.

{{collapse top|From [[Special:Diff/1324292862|this November 2025 revision]] to [[Michelle Osis]]}}
<syntaxhighlight lang="wikitext">
<ref>{{cite web
 |title=Canadian Screen Music Awards 2025 Winners and Nominees
 |url=URL
 |website=Canadian Screen Music Awards
 |date=2025
 |access-date=2025-XX-XX
}}</ref>

<ref>{{cite web
 |title=Best Original Score, Dramatic Series or Special – Winner: "Murder on the Inca Trail"
 |url=URL
 |website=Canadian Screen Music Awards
 |date=2025
 |access-date=2025-XX-XX
}}</ref>
</syntaxhighlight>
{{collapse bottom}}

'''Links to searches'''
* [https://en.wikipedia.org/w/index.php?search=insource%3A%2F20%5B0-9%5D%5B0-9%5D-%28XX%7Cxx%29-%28XX%7Cxx%29%2F&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 <nowiki>insource:/20[0-9][0-9]-(XX|xx)-(XX|xx)/</nowiki>]

In some cases, LLM-generated citations may also contain placeholders in other fields.

'''Examples'''
{{collapse top|From [[Special:Diff/1330090335|this December 2025 revision]] to [[Dmitry Kuznetsov (politician)]]}}
<nowiki>{{</nowiki>cite web <br>{{!}}url={{highlight|INSERT_SOURCE_URL_30}} <br>{{!}}title=Deputy Monitoring of Regional Assistance to Mobilized Soldiers <br>{{!}}date={{highlight|2022-11-XX}} <br>{{!}}publisher={{highlight|SOURCE_PUBLISHER}} <br>{{!}}accessdate=2024-07-21<br><nowiki>}}</nowiki>
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1337437306|this February 2026 revision]] to [[Nelly Joy]]}}
<nowiki><ref></nowiki>{{((}}cite web<br /> {{!}}title{{=}}Ecos de Amor – Spotify<br /> {{!}}url{{=}}{{highlight|PASTE_SPOTIFY_TRACK_URL_HERE}}<br /> {{!}}website{{=}}Spotify<br /> {{!}}access-date{{=}}2026-02-09<br />{{))}}<nowiki></ref></nowiki><br /><nowiki><ref></nowiki>{{((}}cite web<br /> {{!}}title{{=}}Jesse & Joy – Ecos de Amor (Official Music Video)<br /> {{!}}url{{=}}{{highlight|PASTE_YOUTUBE_VIDEO_URL_HERE}}<br /> {{!}}website{{=}}YouTube<br /> {{!}}access-date{{=}}2026-02-09<br />{{))}}<nowiki></ref></nowiki>
{{collapse bottom}}

LLM-generated infobox edits may contain comments stating that text or images should be added if sources are found. Note: Comments in infoboxes, especially older infoboxes, are common—some templates automatically include them—and not an indicator of AI use. Anything but "Add ____", or variations on that specific wording, is actually more likely to indicate human text. Even then, there are exceptions; for example, articles with [[:Template:Infobox military person]] often contain the boilerplate "Add spouse if reliably sourced", which predates LLMs.

'''Examples'''
{{blockquote|{{!}} leader_name        {{=}} {{highlight|<nowiki><!-- Add if available with citation --></nowiki>}}|From [[Special:Diff/1301011748|this July 2025 revision]] to [[Pindi Saidpur]]}}

==Markup==

===Use of Markdown===
{{Shortcut|WP:MARKDOWN|WP:AIMARKDOWN}}

A lot of AI chatbots are not proficient in [[H:WT|wikitext]], the [[markup language]] used to instruct Wikipedia's [[MediaWiki]] software how to format an article. As wikitext is a niche markup language, found mostly on Wikipedia, other Wikimedia wikis, and other MediaWiki-based platforms like [[Miraheze]], LLMs wikitext-formatted content is not prominent in their training data. While the corpora of chatbots did ingest millions of Wikipedia articles, these articles would not have been processed as text files containing wikitext syntax.

In chatbot apps, the output display is formatted with Markdown, a markup language conceptually similar to wikitext but much more widely applied. Meanwhile, the chatbots' preprompts typically instruct them to use markdown in their answers, such as when providing lists and writing with headings. That is, their system-level instructions often direct them to format outputs using Markdown, and the chatbot apps render its syntax as formatted text on a user's screen. For example, the system prompt for Claude Sonnet 3.5 (November 2024) includes:<ref name="sonnetprompt">{{cite web |title=System Prompts |url=https://platform.claude.com/docs/en/release-notes/system-prompts#claude-sonnet-3-5 |website=Claude Docs |publisher=Anthropic |access-date=9 January 2026}}</ref>

{{blockquote|Claude uses Markdown formatting. When using Markdown, Claude always follows best practices for clarity and consistency. It always uses a single space after hash symbols for headers (e.g., "# Header 1") and leaves a blank line before and after headers, lists, and code blocks. For emphasis, Claude uses asterisks or underscores consistently (e.g., italic or bold). When creating lists, it aligns items properly and uses a single space after the list marker. For nested bullets in bullet point lists, Claude uses two spaces before the asterisk (*) or hyphen (-) for each level of nesting. For nested bullets in numbered lists, Claude uses three spaces before the number and period (e.g., "1.") for each level of nesting.}}

As the above indicates, Markdown syntax is completely different from wikitext. Markdown uses asterisks (*) or underscores (_) instead of single-quotes (') for bold and italic formatting, hash symbols (#) instead of equals signs (=) for section headings, parentheses (()) instead of square brackets (<nowiki>[]</nowiki>) around URLs, and three symbols (---, ***, or ___) instead of four hyphens (<nowiki>----</nowiki>) for thematic breaks.

When told to "generate an article", chatbots often default to using Markdown for the generated output. This formatting is preserved in clipboard text by the copy functions on some chatbot platforms. If instructed to generate content for Wikipedia, the chatbot might "realize" the need to generate Wikipedia-compatible code, and might include a message like {{tqi|Would you like me to ... turn this into actual Wikipedia markup format (`wikitext`)?}}{{efn|[[Special:PermanentLink/1300700102|Example]] (deleted, administrators only)}} in its output. If the chatbot is told to proceed, the resulting syntax is often rudimentary, syntactically incorrect, or both. The chatbot might put its attempted-wikitext content in a Markdown-style [https://www.markdownguide.org/extended-syntax/#fenced-code-blocks fenced code block] (its syntax for [[WP:PRE]]) surrounded by Markdown-based syntax and content, which may also be preserved by platform-specific copy-to-clipboard functions, leading to a telling footprint of both markup languages' syntax. This might include the appearance of three backticks in the text, such as: <code>```wikitext</code>.{{efn|[[Special:PermanentLink/1297827841|Example]] of {{code|```wikitext}} on a draft.|}}{{efn|See [[WP:AISIGNS/Wikitext wrapped in Markdown code blocks from chatbots]]}}

The presence of faulty wikitext syntax mixed with Markdown syntax is a strong indicator that content is LLM-generated, especially if in the form of a fenced Markdown code block. However, Markdown {{em|alone}} is not such a strong indicator. Software developers, researchers, technical writers, and experienced internet users frequently use Markdown in tools like [[Obsidian (software)|Obsidian]] and [[GitHub Flavored Markdown|GitHub]], and on platforms like [https://support.reddithelp.com/hc/en-us/articles/360043033952-Formatting-Guide Reddit], [https://support.discord.com/hc/en-us/articles/210298617-Markdown-Text-101-Chat-Formatting-Bold-Italic-Underline Discord], and [https://slack.com/help/articles/202288908-Format-your-messages Slack]. Some writing tools and apps, such as [[iOS Notes]], [[Google Docs]], and [[Windows Notepad]], support Markdown editing or exporting. The increasing ubiquity of Markdown may also lead new editors to expect or assume Wikipedia to support Markdown by default.

'''Examples'''
{{see also|Markdown#Examples}}

{{collapse top|From [[User talk:Fileas Fogg#c-Fileas Fogg-20250410203700-I ask that this be considered seriously and in good_faith.|this April 2025 unblock request]] at [[User talk:Fileas Fogg]]}}
I believe this block has become procedurally and substantively unsound. Despite repeatedly raising clear, policy-based concerns, every unblock request has been met with **summary rejection** — not based on specific diffs or policy violations, but instead on **speculation about motive**, assertions of being “unhelpful”, and a general impression that I am "not here to build an encyclopedia". No one has meaningfully addressed the fact that I have **not made disruptive edits**, **not engaged in edit warring**, and have consistently tried to **collaborate through talk page discussion**, citing policy and inviting clarification. Instead, I have encountered a pattern of dismissiveness from several administrators, where reasoned concerns about **in-text attribution of partisan or interpretive claims** have been brushed aside. Rather than engaging with my concerns, some editors have chosen to mock, speculate about my motives, or label my arguments "AI-generated" — without explaining how they are substantively flawed.
{{collapse bottom}}

{{collapse top|From {{diff||1290202502|label=this May 2025 revision}} to [[Talk:Dana Klisanin]]}}
<nowiki>- The Wikipedia entry does not explicitly mention the "Cyberhero League" being recognized as a winner of the World Future Society's BetaLaunch Technology competition, as detailed in the interview with THE FUTURIST ([https://consciouscreativity.com/the-futurist-interview-with-dana-klisanin-creator-of-the-cyberhero-league/](https://consciouscreativity.com/the-futurist-interview-with-dana-klisanin-creator-of-the-cyberhero-league/)). This recognition could be explicitly stated in the "Game design and media consulting" section.</nowiki>
{{collapse bottom}}

As shown below, LLMs incorrectly use {{code|##}} to denote section headings, which MediaWiki interprets as a numbered list.

{{blockquote|
## Geography

Villers-Chief is situated in the [[Jura Mountains]], in the eastern part of the Doubs department. [...]
## History

Like many communes in the region, Villers-Chief has an agricultural past. [...]

## Administration

Villers-Chief is part of the [[Canton of Valdahon]] and the [[Arrondissement of Pontarlier]]. [...]

## Population

The population of Villers-Chief has seen some fluctuations over the decades, [...]
|From [[Special:Diff/1294887075|this June 2025 revision]] to [[Villers-Chief]]}}

=== Broken wikitext===
Since AI chatbots are typically not proficient in wikitext and templates, they often produce faulty syntax. A noteworthy instance is garbled code related to [[Template:AfC submission]], as new editors might ask a chatbot how to submit their [[Wikipedia:Articles for Creation|Articles for Creation]] draft; see [[Special:PermaLink/1299830745#Messed_up_templates|this discussion among AfC reviewers]].

'''Examples'''

{{blockquote|<syntaxhighlight lang="wikitext">
[[Category:AfC submissions by date/<0030Fri, 13 Jun 2025 08:18:00 +0000202568 2025-06-13T08:18:00+00:00Fridayam0000=error>EpFri, 13 Jun 2025 08:18:00 +0000UTC00001820256 UTCFri, 13 Jun 2025 08:18:00 +0000Fri, 13 Jun 2025 08:18:00 +00002025Fri, 13 Jun 2025 08:18:00 +0000: 17498026806Fri, 13 Jun 2025 08:18:00 +0000UTC2025-06-13T08:18:00+00:0020258618163UTC13 pu62025-06-13T08:18:00+00:0030uam301820256 2025-06-13T08:18:00+00:0008amFri, 13 Jun 2025 08:18:00 +0000am2025-06-13T08:18:00+00:0030UTCFri, 13 Jun 2025 08:18:00 +0000 &qu202530;:&qu202530;.</0030Fri, 13 Jun 2025 08:18:00 +0000202568>June 2025|sandbox]]
</syntaxhighlight>|title=From [[Special:PermanentLink/1295363321|this revision]] to [[User:Dr. Omokhudu Idogho/sandbox]]}}

===Internal formatting and reference markup bugs ===
{{Shortcut|WP:OAICITE}}
LLM output sometimes exposes its internal formatting code, which is an unambiguous indicator that the text originated with AI. The specific bugs vary by chatbot or tool.

====ChatGPT: <span class="anchor" id="oaicite"></span> contentReference, oaicite/oai_citation, +1, turn0search0, attributableIndex ====
ChatGPT sometimes adds code in the form of {{code|:contentReference[oaicite:0]{index{{=}}0{{)}}}}, {{code|Example+1}}, or {{code|oai_citation}} in place of links to references in output text.

'''Examples'''
{{collapse top|From {{diff||1294765751|label=this June 2025 revision}} to [[Talk:Sial (tribe)]].}}
:contentReference[oaicite:16]{index{{=}}16}

1. **Ethnicity clarification**
{{pre|
  - :contentReference[oaicite:17]{index{{=}}17}
    * :contentReference[oaicite:18]{index{{=}}18} :contentReference[oaicite:19]{index{{=}}19}.
    * Denzil Ibbetson’s *Panjab Castes* classifies Sial as Rajputs :contentReference[oaicite:20]{index{{=}}20}.
    * Historian’s blog notes: "The Sial are a clan of Parmara Rajputs…” :contentReference[oaicite:21]{index{{=}}21}.
}}
2. :contentReference[oaicite:22]{index{{=}}22}
{{pre|
  - :contentReference[oaicite:23]{index{{=}}23}
    > :contentReference[oaicite:24]{index{{=}}24} :contentReference[oaicite:25]{index{{=}}25}.
}}
{{collapse bottom}}

{{collapse top|From {{diff||1296028135|label=this June 2025 revision}} to [[Talk:Independent Together]]}}
#### 📌 Key facts needing addition or correction:
1. **Group launch & meetings**
{{pre|
   *Independent Together* launched a “Zero Rates Increase Roadshow” on 15 June, with events in Karori, Hataitai, Tawa, and Newtown  [oai_citation:0‡wellington.scoop.co.nz](https://wellington.scoop.co.nz/?p%7B%7B=%7D%7D171473).
}}

2. **Zero-rates pledge and platform**
{{pre|
   The group pledges no rates increases for three years, then only match inflation—responding to Wellington’s 16.9% hike for 2024/25  [oai_citation:1‡en.wikipedia.org](https://en.wikipedia.org/wiki/Independent_Together).
}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1325099471|this November 2025 revision]] to [[ISO/IEC 27017]]}}
This was created conjointly by technical committee ISO/IEC JTC 1/SC 27 (Information security, cybersecurity, and protection of privacy) {{highlight|IT Governance+3ISO+3ISO+3}}. It belongs to the ISO/IEC 27000 family that talks about information security management systems (ISMS) and related practice controls. {{highlight|Wikipedia+1}}. The standard gives guidance for information security controls for cloud service providers (CSPs) and cloud service customers (CSCs). Specifically adapted to cloud specific environments like responsibility, virtualization, dynamic provisioning, and multi-tenant infrastructure. {{highlight|Ignyte+3Microsoft Learn+3Google Cloud+3}}.
{{collapse bottom}}

ChatGPT may include <code>citeturn0search0</code> (surrounded by Unicode points in the [[Private Use Area]]) at the ends of sentences, with the number after "search" increasing as the text progresses. There also exists an alternate shorter form with only the increasing number surrounded by PUA Unicode like <code>0</code>. These are places where the chatbot links to an external site, but a human pasting the conversation into Wikipedia has that link converted into placeholder code. This was first observed in February 2025. Less often, the pattern may appear as a ref name, e.g., <nowiki><ref name="0search12"></nowiki>.

A set of images in a response may also render as <code>iturn0image0turn0image1turn0image4turn0image5</code>. Rarely, other markup of a similar style, such as <code>citeturn0news0</code> ([[Special:PermaLink/1276934509|example]]), <code>citeturn1file0</code> ([[Special:PermaLink/1286349902|example]]), or <code>cite''generated-reference-identifier''</code> ([[Special:PermaLink/1276907078|example]]), may appear.

{{collapse top|From {{diff||1274664396|label=this February 2025 revision}} to [[List of English-medium schools in Bangladesh]]}}
The school is also a center for the US College Board examinations, SAT I & SAT II, and has been recognized as an International Fellowship Centre by Cambridge International Examinations. citeturn0search1

For more information, you can visit their official website: citeturn0search0
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Signs of AI writing/Examples/Reze (Chainsaw Man)|Draft:Reze (Chainsaw Man)]] (2025)}}
* **Japanese:** Reze is voiced by Reina Ueda, an established voice actress known for roles such as Cha Hae-In in ''Solo Leveling'' and Kanao Tsuyuri in ''Demon Slayer''.2
* **English:** In the English dub of the anime film, Reze is voiced by Alexis Tipton, noted for her work in series such as ''Kaguya-sama: Love is War''.3
[...]

The film itself holds a high rating on **Rotten Tomatoes** and has been described as a major anime release of 2025, indicating strong overall reception for the Reze Arc storyline and its adaptation.5
{{collapse bottom}}

ChatGPT may add [[JSON]]-formatted code at the end of sentences in the form of <code>({"attribution":{"attributableIndex":"X-Y"}})</code>, with X and Y being increasing numeric indices.

{{collapse top|From [[Wikipedia:Signs of AI writing/Examples/Aleftina Evdokimova|Draft:Aleftina Evdokimova]] (2025)}}
^[Evdokimova was born on 6 October 1939 in Osnova, Kharkov Oblast, Ukrainian SSR (now Kharkiv, Ukraine).]({"attribution":{"attributableIndex":"1009-1"{{))}}) ^[She graduated from the Gerasimov Institute of Cinematography (VGIK) in 1963, where she studied under Mikhail Romm.]({"attribution":{"attributableIndex":"1009-2"{{))}}) [oai_citation:0‡IMDb](https://www.imdb.com/name/nm0947835/) [oai_citation:1‡maly.ru](https://www.maly.ru/en/people/EvdokimovaA)
{{collapse bottom}}

{{collapse top|From [[:fr:Special:Diff/225259294|this April 2025 revision]] to [[:fr:Syndicalisme aux États-Unis]]}}
Patrick Denice & Jake Rosenfeld, [https://sociologicalscience.com/articles-v5-23-541/ Les syndicats et la rémunération non syndiquée aux États-Unis, 1977–2015], ‘‘Sociological Science’’ (2018).]({“attribution”:{“attributableIndex”:“3795-0”{{))}})
{{collapse bottom}}

'''Links to searches'''
* {{plainlink|url=https://en.wikipedia.org/w/index.php?search=%22contentReference%22+OR+%22oaicite%22+OR+%22oai_citation%22&title=Special%3ASearch "contentReference" OR "oaicite" OR "oai_citation"}}
* {{search link|turn0search0 OR turn0search1 OR turn0search2 OR turn0search3 OR turn0search4 OR turn0search5 OR turn0search6 OR turn0search7}}
* {{search link|turn0image0 OR turn0image1 OR turn0image2 OR turn0image3 OR turn0image4 OR turn0image5 OR turn0image6 OR turn0image7}}
* {{search link|insource:/turn0(search{{!}}image{{!}}news{{!}}file)[0-9]+/}}

====<span class="anchor" id="Gemini"></span> Gemini: [cite: 1], [span_1](start_span) ====
{{shortcut|WP:STARTSPAN}}
Text copied from [[Google Gemini]] may contain <code>[cite: 1]</code> or <code>[cite: 3, 12, 13]</code>style markers.

'''Examples'''
{{collapse top|From [[Wikipedia:Signs of AI writing/Examples/Parmod Maloo|Parmod Maloo]] in February 2026}}
Maloo founded '''Kreative Machinez''' in February 2010{{highlight|[cite: 17]}}.  The agency provides services in search engine marketing, social media marketing, web development, and online branding{{highlight|[cite: 18]}}.  The company employs more than 100 people and has worked with over 1,000 client accounts across sectors such as healthcare, real estate, and e-commerce{{highlight|[cite: 19, 20, 21]}}.
{{collapse bottom}}

Gemini text may also contain formatting bugs in the form of <code>[span_1](start_span)</code> and <code>[span_1](end_span)</code>.

{{collapse top|From {{diff||1363979466|label=this July 2026 revision}} to [[Huey Lewis and the News]]}}
Riding the wave of their soundtrack success, the group released their fourth studio album, ''[[Fore!]]{{highlight|[span_2](start_span)}}'', in August 1986{{highlight|[span_2](end_span)}}. {{highlight|[span_3](start_span)}}The album mirrored the multi-platinum status of its predecessor and topped the ''Billboard'' 200 chart{{highlight|[span_3](end_span)}}. ''Fore{{highlight|[span_4](start_span)}}!'' yielded two number-one singles on the Hot 100}}
{{collapse bottom}}

'''Links to searches'''
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22span+0+start+span%22+OR+%22span+0+end+span%22+OR+%22start+span+span+0%22+OR+%22span+1+start+span%22+OR+%22span+1+end+span%22+OR+%22start+span+span+1%22+OR+%22span+2+start+span%22+OR+%22span+2+end+span%22+OR+%22start+span+span+2%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1&ns1=1&ns2=1&ns3=1&ns4=1&ns5=1&ns6=1&ns7=1&ns8=1&ns9=1&ns10=1&ns11=1&ns12=1&ns13=1&ns14=1&ns15=1&ns100=1&ns101=1&ns118=1&ns119=1&ns126=1&ns127=1&ns710=1&ns711=1&ns828=1&ns829=1&ns1728=1&ns1729=1 "span 0 start span" OR "span 0 end span" OR "start span span 0" OR "span 1 start span" OR "span 1 end span" OR "start span span 1" OR "span 2 start span" OR "span 2 end span" OR "start span span 2"}}
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=insource%3A%22start+span%22+insource%3A%2F%5C%28start_span%5C%29%2F&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1&ns1=1&ns2=1&ns3=1&ns4=1&ns5=1&ns6=1&ns7=1&ns8=1&ns9=1&ns10=1&ns11=1&ns12=1&ns13=1&ns14=1&ns15=1&ns100=1&ns101=1&ns118=1&ns119=1&ns126=1&ns127=1&ns710=1&ns711=1&ns828=1&ns829=1&ns1728=1&ns1729=1 insource:"start span" insource:/\(start_span\)/}}

====<span class="anchor" id="Grok"></span> Grok: grok_card, grok_render_citation_card_json ====
{{shortcut|WP:GROKCARD}}
Text generated by Grok may occasionally include [[XML]]-styled <code>grok_card</code> tags after citations.

'''Examples'''
{{collapse top|From [[Special:PermanentLink/1323207968|this November 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Mehak Malik|Draft:Mehak Malik]]}}
Malik's rise to fame highlights the visibility of transgender artists in Pakistan's entertainment scene, though she has faced societal challenges related to her identity. [...]<nowiki><grok-card data-id="e8ff4f" data-type="citation_card"></nowiki>
{{collapse bottom}}

Grok may also include <code>grok_render_citation_card_json</code> in place of links to reference in the output text.

{{collapse top|From [[Special:Permalink/1352634865|this May 2026 revision]] to [[Wikipedia:Signs of AI writing/Examples/TUSAŞ Gölge tactical UAV|Draft:TUSAŞ Gölge tactical UAV]]}}
Gölge was publicly revealed through trademark and patent applications filed with the Turkish Patent and Trademark Office in April 2026. The platform was showcased at the SAHA Expo 2026 in Istanbul alongside the jet-powered kamikaze UAV AYAZ. [](grok_render_citation_card_json={"cardIds":["3bb883"]})
----
Gölge is a **piston-engine** tactical UAV optimized for long-endurance missions. The name "Gölge" (Shadow) and associated branding suggest a focus on **low-observability** (low radar cross-section) features. It is designed as a flexible, multi-role platform, primarily for intelligence, surveillance, and reconnaissance (ISR) roles. [](grok_render_citation_card_json={"cardIds":["993eac"]})
{{collapse bottom}}

'''Links to searches'''
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22grok-card+data-id%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1&ns1=1&ns2=1&ns3=1&ns4=1&ns5=1&ns6=1&ns7=1&ns8=1&ns9=1&ns10=1&ns11=1&ns12=1&ns13=1&ns14=1&ns15=1&ns100=1&ns101=1&ns118=1&ns119=1&ns126=1&ns127=1&ns710=1&ns711=1&ns828=1&ns829=1&ns1728=1&ns1729=1 grok-card data-id}}

====DeepSeek: lenticular brackets, dagger symbols ====
As of June 2025, markup with [[lenticular brackets]] and [[dagger symbol]]s, like <code>【85†L261-269】</code>, has also been seen. This format appears to be specific to [[DeepSeek]] and its derivatives.<ref>{{cite web|url=https://github.com/subharmonicseed/Synergesis/blob/99a9b959036524552be2fd796f9a8f927ac91549/Syn%20sans%20magie/Synergesis_DeepSeek_Complete_Archive/Syn%20comme%20une%20%C3%A9tude%20de%20march%C3%A9.txt#L83|title=Synergesis_DeepSeek_Complete_Archive text|access-date=11 June 2026}}</ref>

{{collapse top|From [[Special:Permalink/1295285879|this June 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Gillingham High Street|Draft:Gillingham High Street]]}}
Recent initiatives aim to reverse decline. Medway Council’s Gillingham Town Centre Planning Framework (2007) and later Gillingham Business Plan identified preservation of historic shopfronts and pedestrian enhancements as prioritiesmedway.gov.ukmedway.gov.uk. In 2024 MP Naushabah Khan launched the “Love Gillingham” campaign and a high-street taskforce to improve cleanliness, safety and commerce【85†L261-269】. A community panel is drafting a Gillingham Action Plan, and events like the September 2024 “Big Day Out” carnival (2,500+ attendees) help draw people in【85†L269-274】. As of 2025 vacancy rates on the High Street were reported at about 6.2% (well below the 16% UK average)【85†L261-269】, suggesting a modest stability even as big chains have disappeared.}}
{{collapse bottom}}

{{collapse top|From [[Special:Permalink/1304282215|this August 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Paytra|Draft:Paytra]]}}
Paytra Gessler, known professionally as Paytra, is an American singer‑songwriter whose music combines pop and hip‑hop with R&B, funk and soul influences. She gained attention in the early 2020s with her genre‑bending singles and her feminist message. Paytra’s releases include the EP Momma Taught Me How to Fight and the album Tiny But Mighty (both 2023)【854140639155648†L119-L123】, as well as the singles “Villain Era” (2023), “Bright Red Flags” (2023)【331835262276082†L127-L149】, “Good Girls Don’t Make History” (2024)【610406519434033†L284-L290】, “All Kinda Bitches” (2024)【695032903925577†L42-L52】 and “World’s About to Get Crazy” (2024)【466616601965079†L42-L60】.}}
{{collapse bottom}}

{{collapse top|From [[Wikipedia:Signs of AI writing/Examples/JAF-GT300|Draft:JAF-GT300]] in March 2026}}
<syntaxhighlight lang="wikitext">
JAF-GT300 cars are generally Japanese makes or specially constructed “silhouette” vehicles, distinct from the FIA [[Group GT3]] cars, also eligible in GT300【29†L582-L589】. The Japan Automobile Federation (JAF) is the national motorsport authority in Japan and co-sponsors Super GT, setting technical rules for JAF-GT cars【32†L142-L149】. In practice, a GT300 field includes three types of cars: (1) **JAF-GT** cars (JAF-regulation, often modified Japanese road cars or special designs), (2) **FIA GT3** cars (homologated under FIA GT3 rules), and (3) **Mother Chassis** (MC) cars (built on a standard tubular chassis by Dome)【29†L598-L606】.
</syntaxhighlight>
{{collapse bottom}}

'''Links to searches'''
* {{plainlink|url=https://en.wikipedia.org/w/index.php?search=insource%3A%2F%E3%80%90%5B0-9%5D%2B%E2%80%A0%2F&title=Special%3ASearch&profile=advanced&fulltext=1&ns118=1 insource:/【[0-9<nowiki>]</nowiki>+†/}} (in drafts only)

====Perplexity: attached_file, ppl-ai-file-upload ====
As of fall 2025, tags like <code><nowiki>[attached_file:1]</nowiki></code> and <code><nowiki>[web:1]</nowiki></code> have been seen at the end of sentences. This may be [[Perplexity AI|Perplexity]]-specific.<ref name="wildperplexityappeared">{{cite web |title=Unproductive Interpretation of Work and Employment as Misinformation? |url=https://www.laetusinpraesens.org/docs20s/workeco.php |access-date=21 October 2025 |archive-date=2 September 2025 |archive-url=https://web.archive.org/web/20250902133810/https://www.laetusinpraesens.org/docs20s/workeco.php |url-status=live }}</ref>

{{blockquote|
During his time as CEO, Philip Morris’s reputation management and media relations brought together business and news interests in ways that later became controversial, with effects still debated in contemporary regulatory and legal discussions.[attached_file:1]
|title=From {{diff||1316436509|label=this October 2025 revision}} to [[Hamish Maxwell]]}}

Perplexity may also cite text to an [[Amazon S3]] bucket, with <code>ppl-ai-file-upload</code> in the URL.

'''Links to searches'''
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22ppl-ai-file-upload%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1&ns2=1&ns118=1 "ppl-ai-file-upload"}}

====Unclassified: :::writing====
As of June 1, 2026, markup in the format <code>:::writing{variant="document" id="[NUMBER]"}</code>, where [NUMBER] is a random 5-digit number, has been spotted; the triple colons at the beginning may or may not be interpreted as an indent. Triple colons at the end of the "document" are often paired with this. The markup may or may not be in other languages.

'''Examples'''
{{collapse top|From [[Special:Permalink/1358854076|this June 2026 revision]] to [[User:Drrbharanidharan]]}}
I can help draft a Wikipedia-style biography, but I should be clear: a page written this way is not automatically suitable for Wikipedia. Wikipedia requires facts to be supported by independent, reliable sources, and promotional or unsourced claims may be removed.

Based only on the information you've shared with me, here's a professional encyclopedia-style draft:

:::{{highlight|<nowiki>writing{variant="document" id="68427"}</nowiki>}}
{{collapse bottom}}

{{collapse top|From [[Special:Permalink/1357217465|this June 2026 revision]] to [[Draft:Ak7]]}}
<syntaxhighlight lang="wikitext">:::écriture{variante="document" id="28471"} == AK7== '''AK7''', aussi connu sous le nom de '''Yanixak7''', [...] == Discographie == === Célibataires ===	 •	 « Digba Kistha » (2022)	 •	 ''Tals'' (2025) == Privilèges externes ==
pédia :

:::writing{variant=“document” id=“51724”}
== Liens externes ==
</syntaxhighlight>
[external links omitted]
<syntaxhighlight lang="wikitext">
:::

Et petite corr :::
</syntaxhighlight>
{{collapse bottom}}

=== Non-existent or out-of-place categories ===
{{shortcut|WP:AIREDCAT}}
LLMs may hallucinate non-existent categories, sometimes for generic concepts that ''seem like'' plausible category titles (or [[search engine optimization|SEO]] keywords), and sometimes because their training set includes obsolete and renamed categories. These will appear as [[WP:REDNOT|red links]]. You may also find category redirects, such as the longtime spammer favorite [[:Category:Entrepreneurs]]. Sometimes, broken categories may be deleted by reviewers, so if you suspect a page may be LLM-generated, it may be worth checking earlier revisions.

Of course, none of this section should be treated as a hard-and-fast rule. New users are unlikely to know about Wikipedia's style guidelines for these sections, and returning editors may be used to old categories that have since been deleted.

'''Examples'''
{{blockquote|<syntaxhighlight lang="wikitext">[[Category:American hip hop musicians]]</syntaxhighlight>|title=From [[Special:PermanentLink/1304282215|this August 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Paytra|Draft:Paytra]]}}
rather than
{{blockquote|<syntaxhighlight lang="wikitext">[[Category:American hip-hop musicians]]</syntaxhighlight>}}

=== Non-existent templates ===
LLMs often hallucinate non-existent templates (especially plausible-sounding types of [[WP:infoboxes|infoboxes]]) and template parameters. These will also appear as red links, and non-existent template parameters in existing templates have no effect. LLMs may also use templates that were deleted after their knowledge cutoff date (such as the [[Wikipedia:Templates for discussion/Log/2024 September 27/lang-?? templates|lang-?? series]]).

'''Examples'''
{{blockquote|
<syntaxhighlight lang="wikitext">
{{Infobox ancient population
| name = Gangetic Hunter-Gatherer (GHG)
| image = [[File:GHG_reconstruction.png|250px]]
| caption = Artistic reconstruction of a Gangetic Hunter-Gatherer male, based on Mesolithic skeletal data from the Ganga Valley
| regions = Ganga Valley (from Haryana to Bengal, between the Vindhyas and Himalayas)
| period = Mesolithic–Early Neolithic (10,000–5,000 BCE)
| descendants = Gangetic peoples, Indus Valley Civilisation, South Indian populations
| archaeological_sites = Bhimbetka, Sarai Nahar Rai, Mahadaha, Jhusi, Chirand
}}
</syntaxhighlight>
|From [[Special:PermanentLink/1326132735|this revision]] to [[Wikipedia:Signs of AI writing/Examples/Gangetic hunter-gatherers|Draft:Gangetic hunter-gatherers]]}}
rather than
{{blockquote|<syntaxhighlight lang="wikitext">
{{Infobox archaeological culture
| name = Gangetic Hunter-Gatherer (GHG)
| map = [[File:GHG_reconstruction.png|250px]]
| mapcaption = Artistic reconstruction of a Gangetic Hunter-Gatherer male, based on Mesolithic skeletal data from the Ganga Valley
| region = Ganga Valley (from Haryana to Bengal, between the Vindhyas and Himalayas)
| period = Mesolithic–Early Neolithic (10,000–5,000 BCE)
| followedby = Gangetic peoples, Indus Valley Civilisation, South Indian populations
| majorsites = Bhimbetka, Sarai Nahar Rai, Mahadaha, Jhusi, Chirand
}}
</syntaxhighlight>
}}
'''Non-infobox examples'''
{{blockquote|
<syntaxhighlight lang="wikitext">
== <!-- EDIT BELOW THIS LINE --> == markup
{{Update submission |reasons=Complete biographical rewrite executed to strip out promotional prose. Incorporated independent third-party literary journal analysis from Ashvamegh Journal to satisfy WP:NBIOGRAPHY. |ts=2026-06-08T12:19:00Z}}
</syntaxhighlight>
|From [[Special:PermanentLink/1358339625|this revision]] to [[User:Blueskyreader/sandbox]]}}

==== Links to searches ====
* [[Wikipedia:Database reports/Transclusions of non-existent templates]] – many of these broken templates are legitimate mistakes, but the "infobox" and "lang" sections are likely to contain LLM hallucinations

== Citations ==
{{For|non-AI-specific guidance about this|Wikipedia:Fictitious references}}
{{Shortcut|WP:AIFICTREF}}
{{See also|Template:Failed verification}}

=== Broken external links ===
If a new article or draft has multiple citations with external links, and '''several''' of them are broken (e.g., non-existent websites or [[404 error]]s), this is a strong sign of an AI-generated page, particularly if the dead links are not found in website archiving sites like the [[Internet Archive]]. Most links [[link rot|become broken over time]], but these factors make it unlikely that the link was ever real.

Watch out for:  Links that don't work for you, but do work for other people (e.g., journal articles accessed through a university library); links that were mangled by bots and scripts (e.g., to add incorrect identifiers or to remove seemingly unnecessary parts of the URL); links that are missing the start or end (a sign of a human copy/pasting the URL).

===Invalid DOI and ISBNs===
{{For|non-AI-specific guidance about DOI and ISBNs|Wikipedia:DOI|Wikipedia:ISBN}}
A [[checksum]] can be used to verify [[ISBN]]s. An invalid checksum is a very likely sign that an ISBN is incorrect, and citation templates display [[Help:CS1 errors#bad isbn|a warning]] if so. Similarly, [[Digital object identifier|DOI]]s are more resistant to link rot than regular hyperlinks. Unresolvable DOIs and invalid ISBNs can be indicators of [[Hallucination (AI)|hallucinated]] references.

===DOIs that lead to unrelated articles===
A LLM may generate references to non-existent scholarly articles with DOIs that appear valid but are, in reality, assigned to unrelated articles. Example passage generated by ChatGPT:

<blockquote>
Ohm’s Law applies to many materials and components that are "ohmic," meaning their resistance remains constant regardless of the applied voltage or current. However, it does not hold for non-linear devices like diodes or transistors [1][2].

1. M. E. Van Valkenburg, “The validity and limitations of Ohm’s law in non-linear circuits,” Proceedings of the IEEE, vol. 62, no. 6, pp. 769–770, Jun. 1974. {{doi|10.1109/PROC.1974.9547}}

2. C. L. Fortescue, “Ohm’s Law in alternating current circuits,” Proceedings of the IEEE, vol. 55, no. 11, pp. 1934–1936, Nov. 1967. {{doi|10.1109/PROC.1967.6033}}
</blockquote>

Both ''Proceedings of the IEEE'' citations are completely made up. The DOIs lead to different citations and have other problems as well. For instance, [[Charles LeGeyt Fortescue|C. L. Fortescue]] was dead for 30+ years at the purported time of writing, and [https://ieeexplore.ieee.org/xpl/tocresult.jsp?isnumber=31102&punumber=5 Vol 55, Issue 11] does not list any articles that match anything remotely close to the information given in reference 2.

Note: From 2018 to 2023, [https://phabricator.wikimedia.org/T198456 a UX issue in VisualEditor] led many editors to accidentally insert references to [[PubMed]] articles with low ID numbers (PMIDs), resulting in obviously irrelevant citations like an article about rat livers (PMID 9) being cited in [[Special:Diff/972043377|List of Disney television films]] in 2020. These may resemble AI hallucinations (and should be fixed regardless), but they generally are not.

===Book citations without page numbers or URLs===
LLMs often generate book citations that do not include page numbers. This passage, for example, was generated by ChatGPT:
<blockquote>
Ohm's Law is a fundamental principle in the field of electrical engineering and physics that states the current passing through a conductor between two points is directly proportional to the voltage across the two points, provided the temperature remains constant. Mathematically, it is expressed as V=IR, where V is the voltage, I is the current, and R is the resistance. The law was formulated by German physicist Georg Simon Ohm in 1827, and it serves as a cornerstone in the analysis and design of electrical circuits [1].

1. Dorf, R. C., & Svoboda, J. A. (2010). Introduction to Electric Circuits (8th ed.). Hoboken, NJ: John Wiley & Sons. {{ISBN|9780470521571}}.
</blockquote>

The book reference appears valid – a book on electric circuits would likely have information about Ohm's law – but without the page number, that citation is not useful for verifying the claims in the prose.

Some LLM-generated book citations include page numbers, and the book exists, but the cited pages do not verify the text. Signs to look out for: the book is on a somewhat general topic or frequently referenced in its field, and the citation does not include a URL (not mandatory for book citations, but editors creating legitimate book citations often include a link to [[Wikipedia:Book_sources#Online_text|an online version of the text]]). Example:

<blockquote>
Analysts note that traditionalists often appeal to prudence, stability, and Edmund Burke’s notion of “prescription,” while reactionaries invoke moral urgency and cultural emergency, framing the present as a deviation from an idealized past. [1]

1. Goldwater, Barry (1960). The Conscience of a Conservative. Victor Publishing. p. 12.
</blockquote>

This may look like a reasonable citation, but searching an [https://www.google.com/books/edition/The_Conscience_of_a_Conservative/PKd_EQAAQBAJ?hl=en&gbpv=1&bsq=burke online version of the book for "Burke" produces no results].

=== Incorrect or unconventional use of references ===
{{Shortcut|WP:AICITESTYLE}}

AI tools may have been prompted to include references, and make an attempt to do so as Wikipedia expects, but fail with some key implementation details or stand out when compared with conventions.

'''Examples'''

In the first example, note the incorrect attempt at re-using references. The tool used there was not capable of searching for non-confabulated sources (as it was done the day before [[Microsoft Bing|Bing]] Deep Search launched) but nonetheless found one real reference. The syntax for re-using the references was incorrect.

In that case, the ''Smith, R. J.'' source – being the "third source" the tool presumably generated the link 'https://pubmed.ncbi.nlm.nih.gov/3' (which has a PMID reference of 3) – is also completely irrelevant to the body of the article. The user did not check the reference before they converted it to a {{tl|cite journal}} reference, even though the links resolve.

The LLM in that case has diligently included the incorrect re-use syntax after every single full stop.

{{collapse top|From [[Special:PermanentLink/1188218670|this December 2023 revision]] to [[Cognitive orthotics]]}}
<syntaxhighlight lang="wikitext">
For over thirty years, computers have been utilized in the rehabilitation of individuals with brain injuries. Initially, researchers delved into the potential of developing a "prosthetic memory."<ref>Fowler R, Hart J, Sheehan M. A prosthetic memory: an application of the prosthetic environment concept. ''Rehabil Counseling Bull''. 1972;15:80–85.</ref> However, by the early 1980s, the focus shifted towards addressing brain dysfunction through repetitive practice.<ref>{{Cite journal |last=Smith |first=R. J. |last2=Bryant |first2=R. G. |date=1975-10-27 |title=Metal substitutions incarbonic anhydrase: a halide ion probe study |url=https://pubmed.ncbi.nlm.nih.gov/3 |journal=Biochemical and Biophysical Research Communications |volume=66 |issue=4 |pages=1281–1286 |doi=10.1016/0006-291x(75)90498-2 |issn=0006-291X |pmid=3}}</ref> Only a few psychologists were developing rehabilitation software for individuals with Traumatic Brain Injury (TBI), resulting in a scarcity of available programs.<sup>[3]</sup> Cognitive rehabilitation specialists opted for commercially available computer games that were visually appealing, engaging, repetitive, and entertaining, theorizing their potential remedial effects on neuropsychological dysfunction.<sup>[3]</sup>
</syntaxhighlight>
{{collapse bottom}}

Some LLMs or chatbot interfaces use the character <kbd>↩</kbd> around footnotes. The character is often used on other websites to provide a link for the user to jump back to the article after reading the footnote.

{{collapse top|From [[Special:PermaLink/1304723248|this August 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/CureMD|Draft:CureMD]]}}
{{fake heading|References}}
Would you like help formatting and submitting this to Wikipedia, or do you plan to post it yourself? I can guide you step-by-step through that too.

'''Footnotes'''

# KLAS Research. (2024). ''Top Performing RCM Vendors     2024''. <nowiki>https://klasresearch.com</nowiki> ↩ ↩<sup>2</sup>
# PR Newswire. (2025, February 18). ''CureMD AI Scribe     Launch Announcement''. <nowiki>https://www.prnewswire.com/news-releases/curemd-ai-scribe</nowiki> ↩
{{collapse bottom}}

===utm_source{{=}}===

ChatGPT may add the [[UTM parameter]]s <code>utm_source=openai</code> or <code>utm_source=chatgpt.com</code> to URLs that it is using as sources. Microsoft Copilot may add <code>utm_source=copilot.com</code> to URLs. Grok uses <code>referrer=grok.com</code>. Other LLMs, such as Gemini or Claude, use UTM parameters less often.{{efn|See {{phab|T387903}}.}}

Note: While this near-definitively proves ChatGPT's involvement,{{efn|There are a few rare exceptions: for instance, Google has occasionally indexed URLs containing this parameter, which will remain if you click those results.}} it doesn't prove, on its own, that ChatGPT also generated the writing. Some editors use AI tools to find citations for existing text; this will be apparent in the edit history.

'''Examples'''
{{blockquote|text=Following their marriage, Burgess and Graham settled in Cheshire, England, where Burgess serves as the head coach for the Warrington Wolves rugby league team. <nowiki>[https://www.theguardian.com/sport/2025/feb/11/sam-burgess-interview-warrington-rugby-league-luke-littler</nowiki>{{highlight|?utm_source{{=}}chatgpt.com}}]
|title=From {{diff||1277944793|label=this revision}} to [[Sam Burgess]]
}}

====Links to searches====
*[https://en.wikipedia.org/w/index.php?search=%utm_source=chatgpt.com%22&title=Special:Search&profile=advanced&fulltext=1&ns0=1 utm_source=chatgpt.com]
*[https://en.wikipedia.org/w/index.php?search=insource%3A%22utm_source%3Dchatgpt.com%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 insource:"utm_source=chatgpt.com"]
*[https://en.wikipedia.org/w/index.php?search=insource%3A%22utm_source%3Dopenai%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 insource:"utm_source=openai"]
*[https://en.wikipedia.org/w/index.php?search=insource%3A%22utm_source%3Dcopilot.com%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 insource:"utm_source=copilot.com"]
*[https://en.wikipedia.org/w/index.php?search=insource%3A%22referrer%3Dgrok.com%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 insource:"referrer=grok.com"]

=== Named references declared in references section but unused in article body ===
A common referencing error produced by LLMs involves sources in a <syntaxhighlight lang="wikitext" inline><references></syntaxhighlight> tag which are not used inline.  LLMs can also produce [[WP:NAMEDREF|named references]] which are not defined, although this can also be the result of a copy-paste from a different article.
'''Examples'''
{{collapse top|From [[Special:Diff/1291491974#References|this May 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Josef von Rickenbach|Draft:Josef von Rickenbach]]}}
<syntaxhighlight lang="wikitext">
<references>
<ref name=\"fiercebiotech\">https://www.fiercebiotech.com/cro/parexel-co-founder-josef-von-rickenbach-to-end-35-year-run-as-ceo</ref>
<ref name=\"statnews\">https://www.statnews.com/2018/03/16/parexel-josef-von-rickenbach-cro/</ref>
<ref name=\"mclean\">https://www.mcleanhospital.org/news/three-prominent-community-members-join-mcleans-board</ref>
<ref name=\"twst\">https://www.twst.com/bio/josef-h-von-rickenbach/</ref>
</references>
</syntaxhighlight>
{{fake heading|level=4|Result}}
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "\"fiercebiotech\"" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}<br>
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "\"statnews\"" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}<br>
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "\"mclean\"" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}<br>
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "\"twst\"" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}
{{collapse bottom}}

{{collapse top|From [[Special:Diff/1291558682#References|this May 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Caligomos Art|Draft:Caligomos Art]]}}
<syntaxhighlight lang="wikitext">
<references><ref name="wooart-about">[https://wooart.ca/about-caligomos-art About Caligomos Art – WOO ART]</ref> <ref name="wooart-home">[https://wooart.ca/ Home – WOO ART]</ref> <ref name="discover-leeds">[https://discoverdirectory.leedsgrenville.com/Home/View/woo-art-gallery Woo Art Gallery – Discover Leeds Grenville]</ref> <ref name="book-amazon">Woo, John HR. ''The Book of Caligomos Art''. Amazon KDP, 2025. ISBN 979-8-987654321-0.</ref></references>
</syntaxhighlight>
{{fake heading|level=4|Result}}
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "wooart-about" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}<br>
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "wooart-home" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}<br>
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "discover-leeds" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}<br>
{{error|Cite error: A [[Help:Footnotes#WP:LDR|list-defined reference]] named "book-amazon" is not used in the content (see the [[Help:Cite errors/Cite error references missing key|help page]]).}}
{{collapse bottom}}

'''Links to searches'''
* [[:Category:Pages with incorrect ref formatting]]
* {{plain link|url=https://en.wikipedia.org/w/index.php?title=Special:WhatLinksHere/Template:No_footnotes&hidelinks=1&hidetrans=1 Pages without inline citations}}
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22Cite+error%3A+A+list-defined+reference+named%22+%22is+not+used+in+the+content+%28see+the+help+page%29.%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1&ns2=1&ns118=1 "Cite error: A list-defined reference named" + "is not used in the content (see the help page)."}}

== <span class="anchor" id="Comments"></span> Comment-specific indicators ==
{{shortcut|WP:AICOMMENT|WP:AICOMMENTS}}
{{further|Wikipedia:Signs of AI-generated comments}}
{{see also|Wikipedia:Identifying LLM unblock requests|Wikipedia:The LLM-written ANI report}}

<nowiki>In many cases, some users have copy-pasted text from AI chatbots into their comments. Comments suspected of having been pasted from an LLM may be collapsed via {{</nowiki>[[Template:Collapse AI|collapse AI]]<nowiki>}} per </nowiki>[[WP:AITALK]]. Asides from making any of the mistakes listed on this page, editors who use large language models or similar technology to write their comments are also likely to:
* [[WP:AIFICTPOLICY|Misquote policies and guidelines]] and [[WP:AISHORTCUT|cite made-up shortcuts]] that don't lead to any existing project page.
* [[WP:AITRANSCLUSION|Transclude maintenance banners]] whenever they mention them.
* Post lengthy comments [[WP:AISECTION|divided into sections with titles]], either written in [[WP:MARKDOWN|Markdown]], plain text, or as [[WP:AISUBHEADING|level-2 or level-3 subheadings]].
* [[WP:AIASSURANCE|Assure]] other editors that the content they have produced adheres to Wikipedia's policies and guidelines, or that they are trying to make sure of that.
* [[WP:AIWANTFEEDBACK|Request input from other editors]] to help them determine [[WP:WHERESTHEAI|exactly what they need to improve]].
* Accuse those who call them out for AI use of [[WP:CAAAOS|acting on speculation]] based on their [[WP:STYLISTIC|writing style]] and [[WP:NOPROOFOFAI|failing to present stronger evidence]] that they used AI.

'''Links to searches'''<!-- This is for phrases that may be associated with multiple indicators; for example, a phrase like "to ensure the article adheres to Wikipedia's" may be associated with both WP:AIADHERE and WP:CORCC -->
{|
|
* to ensure the article/content/draft/page...
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+the+article+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+the+content+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+the+draft+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+the+page+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+it+adheres+to+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 adheres to Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+the+article+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+the+content+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+the+draft+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+the+page+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+it+aligns+with+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 aligns with Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+the+article+complies+with+Wikipedia%27s%22+OR+%22to+ensure+the+content+complies+with+Wikipedia%27s%22+OR+%22to+ensure+the+draft+complies+with+Wikipedia%27s%22+OR+%22to+ensure+the+page+complies+with+Wikipedia%27s%22+OR+%22to+ensure+it+complies+with+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 complies with Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+the+article+follows+Wikipedia%27s%22+OR+%22to+ensure+the+content+follows+Wikipedia%27s%22+OR+%22to+ensure+the+draft+follows+Wikipedia%27s%22+OR+%22to+ensure+the+page+follows+Wikipedia%27s%22+OR+%22to+ensure+it+follows+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 follows Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+the+article+meets+Wikipedia%27s%22+OR+%22to+ensure+the+content+meets+Wikipedia%27s%22+OR+%22to+ensure+the+draft+meets+Wikipedia%27s%22+OR+%22to+ensure+the+page+meets+Wikipedia%27s%22+OR+%22to+ensure+it+meets+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 meets Wikipedia's ...}}
|
* to ensure that the article/content/draft/page...
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+that+the+article+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+that+the+content+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+that+the+draft+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+that+the+page+adheres+to+Wikipedia%27s%22+OR+%22to+ensure+that+it+adheres+to+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 adheres to Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+that+the+article+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+that+the+content+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+that+the+draft+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+that+the+page+aligns+with+Wikipedia%27s%22+OR+%22to+ensure+that+it+aligns+with+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 aligns with Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+that+the+article+complies+with+Wikipedia%27s%22+OR+%22to+ensure+that+the+content+complies+with+Wikipedia%27s%22+OR+%22to+ensure+that+the+draft+complies+with+Wikipedia%27s%22+OR+%22to+ensure+that+the+page+complies+with+Wikipedia%27s%22+OR+%22to+ensure+that+it+complies+with+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 complies with Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+that+the+article+follows+Wikipedia%27s%22+OR+%22to+ensure+that+the+content+follows+Wikipedia%27s%22+OR+%22to+ensure+that+the+draft+follows+Wikipedia%27s%22+OR+%22to+ensure+that+the+page+follows+Wikipedia%27s%22+OR+%22to+ensure+that+it+follows+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 follows Wikipedia's ...}}
** {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22to+ensure+that+the+article+meets+Wikipedia%27s%22+OR+%22to+ensure+that+the+content+meets+Wikipedia%27s%22+OR+%22to+ensure+that+the+draft+meets+Wikipedia%27s%22+OR+%22to+ensure+that+the+page+meets+Wikipedia%27s%22+OR+%22to+ensure+that+it+meets+Wikipedia%27s%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns1=1&ns3=1&ns4=1&ns5=1&ns119=1 meets Wikipedia's ...}}
|}

== <span class="anchor" id="Edit summaries"></span> Edit summaries ==
{{Shortcut|WP:AISUMMARY|WP:AISUMM}}
In general, AI-generated [[Help:Edit summary|edit summaries]] are often written as formal, first-person paragraphs, without [[Wikipedia:Edit summary legend|abbreviations]], and conspicuously echo the exact text of Wikipedia's policies or any maintenance tags on the article—for example, [[WP:AIADHERENCE|itemizing their adherence]] to "WP:NPOV" or "encyclopedic tone." They often mention things that they "ensured" or "avoided" doing, or include verbose justifications of minor edits; this is especially obvious if AI is used to "fix" text following suspicion of AI-use.
They may also include other signs on this list, such as [[WP:AIVOCAB|AI vocabulary]], [[WP:AIEMOJI|emoji]], (attempted) [[WP:AILIST|list]] formatting, or [[WP:MARKDOWN|markdown]] formatting. This section contains specific explanations and examples of some of the most common signs which are strongly indicative of AI generated edit summaries.

AI edit summaries strongly suggest that the edits themselves are also AI-generated, as it is unlikely someone would use AI for a simple summary but not the much more time-consuming task of writing.

=== General examples ===
{{ctop|Edit summary from [[Special:Diff/1169501852|this August 2023 revision]] to [[Indira Gandhi National Centre for the Arts]]|expand=yes}}
ChatGPT I revised the content to provide a neutral and informative description of the Indira Gandhi National Centre for the Arts (IGNCA). The focus was on presenting the institution's objectives, approach, and programs in a way that adheres to Wikipedia's guidelines. The tone was adjusted to be more encyclopedic and less promotional.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1293085006|this May 2025 revision]] to [[Anaganaga (film)]]}}**Concise edit summary:** Improved clarity, flow, and readability of the plot section; reduced redundancy and refined tone for better encyclopedic style.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1337450779|this February 2026 revision]] to [[Proposed acquisition of Warner Bros. Discovery by Paramount Skydance]]}}
Reorganized article per RfC to address structural and content management concerns. Separated responses into four sections: Government (senators, DOJ, antitrust review, court hearings), Industry (guilds, trade orgs, notable industry figures), Shareholder (WBD shareholder actions/votes), and Foreign (international regulatory reviews and executive meetings). Background is now limited to developments only: reduced news-style phrasing and close paraphrasing.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1347582895|this April 2026 revision]] to [[COVID-19 pandemic in Montreal]]; also note ChatGPT UTM parameters}}
Added sourced Impact section including restrictions, healthcare strain, and economic effects (2020–2022).
{{cbot}}

{{ctop|Edit summary (with chatbot preamble) from [[Special:AbuseLog/44428512]], June 2026}}
Claude responded: That last sentence is the killer — "Subject meets WP:BIO" — you're speaking their language and daring them to argue with it.Comprehensive rewrite: Early life sourced from University of Miami Athletics official roster (1984–85, LB #85, 6'3" 210 lbs); modeling career documented via Phillips auction house (Bruce Weber direct quote), Holden Luntz Gallery, Artsy, theFashionSpot, and eBay archival listings confirmin
{{cbot}}

More examples (albeit shorter than summaries from current LLMs) can be found [https://huggingface.co/datasets/msakota/edisum_dataset in this dataset] of edit summaries generated with GPT 3.5-turbo.

=== Canned assurance of adherence to Wikipedia policies and guidelines ===
{{tmbox|image=none|text=Words to watch: {{strong| ensured that... adheres to, improved, in compliance/complies with, revised, verifiability, neutrality, neutral tone, encyclopedic tone}} }}

In line with the [[WP:AIASSURE|similarly-named comment-specific sign]], AI generated edit summaries will often reassure the reader to a nearly self-conscious extent that the edit was made in compliance with various Wikipedia PAGs like neutrality and sourcing requirements.

Human editors do occasionally express that they are editing text because it violates a particular manual of style entry or guideline, but this is normally done in a brief and specific manner with a link to the particular item. For example, "removed excessive links per [[MOS:OVERLINK]]", whereas the AI-generated equivalent is usually more verbose and yet less specific (because the human editor behind the bot does not know the relevant guidelines to be able to prompt anything more specific than "make this more neutral"), explaining that they reorganised a section to "ensure neutrality," "improve attribution," "comply with the manual of style" or the likes.

The more of these assurances there are stacked in a single edit summary, especially if they cover a wide variety of "improvements" that a human editor is less likely to cover in a single edit, the stronger the sign.

{{ctop|Edit summary from [[Special:Diff/1363764012|this July 2026 revision]] to [[GPT-4o]]|expand=yes}}
Revised the Capabilities section for clarity and <mark>compliance with the Manual of Style;</mark> removed unnecessary language parameters, consolidated overlapping fine-tuning sections, <mark>corrected promotional wording,</mark> and distinguished preprints from established findings.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1363721990|this July 2026 revision]] to [[Angel Studios]]}}
Updated the feature-film section with current release information, added coverage of David and Solo Mio, corrected Sound of Freedom details, and <mark>improved sourcing and neutrality.</mark>
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1363709326|this July 2026 revision]] to [[Carol Milne]]}}
Reorganize and copyedit <mark>for a more neutral tone.</mark> Condensed lists. <mark>Removed promotional</mark> and mostly unrelated material. <mark>Improve citations</mark> with museums, grant-organization, independent arts sources, etc. Added 2026 SOLA Award.
{{cbot}}

=== Specific mentions of "preserved" or "retained" information ===
{{tmbox|image=none|text=Words to watch: {{strong| preserved/preserving, retained/retaining}} }}

It is unusual for a human edit summary to include mention of material which was not edited. It is, however, exactly what one might expect from an AI which has been prompted to edit the article to accomplish X and Y but to specifically preserve or avoid changing Z.

Note (as is also shown in the examples below) that this typically goes hand in hand with the vague, canned assurances of adherence to/improvement in line with the PAGs/the MOS also discussed in this section; in the format of "Revised [section] to [improve/ensure/etc] [neutrality/verifiability/etc] while preserving [whatever]" or the inverse.

{{ctop|Edit summary from [[Special:Diff/1363763742|this July 2026 revision]] to [[Space Systems Processing Facility]]|expand=yes}}
Removed promotional language and revised the passage to use a more neutral, balanced tone <mark>while preserving the original meaning and technical details.</mark>
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1364008360|this July 2026 revision]] to [[University of Navarra]]}}
...<mark>preserved existing structure and lead emphasis</mark> while improving verifiability, neutrality, layout and consistency.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1363959211|this July 2026 revision]] to [[Larry Meistrich]]}}Updated Red Coral Universe section... added... to the founding team; added Young’s Head of Content and Bizati’s Head of Acquisitions roles; <mark>preserved references and categories</mark>.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1363858070|this July 2026 revision]] to [[Manosphere]]}}
Reworded lead and body for neutrality and balance: attributed contested claims to critics/sources, noted internal diversity of views, clarified Peterson's position as adjacent rather than core, and removed loaded phrasing <mark>while preserving sourced criticisms.</mark>
{{cbot}}

=== Overemphasis on presence/reliability of citations ===
{{tmbox|image=none|text=Words to watch: {{strong| added sourced [information/content/infobox/section], added [coverage/citations/references], improved attribution}} }}

One of the common general signs of AI generated text is the tendency to [[WP:AIATTR|allude to the existence of coverage but not actually summarise the content of that coverage]]. A similar form of this manifests in edit summaries, where an excessive focus is placed on the fact that the content added is "sourced", "closely attributed" to "reliable sources", that "citations" or "coverage" were added, and so on.

A human editor is far more likely to focus on the actual content of the prose they added (e.g., "Added info about the artist's debut"} rather than only vaguely mentioning the source that information is linked to.

{{ctop|Edit summary from [[Special:Diff/1363765282|this July 2026 revision]] to [[Myotherapy]]|expand=yes}}
Build out Professional associations, Regulatory status, and Scope of practice sections <mark>with sourced content;</mark> add Exercise Physiology row to comparison table <mark>with ESSA citations</mark>
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1363991030|this July 2026 revision]] to [[Alexandr Bilinkis]]}}Expanded the article with new sections, <mark>added sourced information, references,</mark> and internal/external links.
{{cbot}}

{{ctop|Edit summary from [[Special:Diff/1363970071|this July 2026 revision]] to [[Culture of Japan]]}}
Add <mark>sourced Military culture section</mark> covering samurai households,literature, ritual, religion, firearms, naval traditions, martial training, medicine, games and Meiji-era bushidō.
{{cbot}}

=== Reference to AfC review ===
AI edit summaries following a decline at AfC will often specifically mention that the edits were made to address the feedback given by the reviewer, a statement so obvious that a human would not typically feel the need to state it.

{{blockquote|<mark>Addressing reviewer feedback</mark> by integrating independent secondary coverage from mainstream financial media.|2=from [[Special:Diff/1357190252|this June 2026 edit]] to [[Draft:Yes Securities]]}}

{{blockquote|Rewrote from scratch <mark>per reviewer feedback.</mark> All claims verified. Added ISNI.|2=from [[Special:Diff/1363498526|this July 2026 edit]] to [[Draft:Millat Mohammed]]}}

{{blockquote|<mark>Addressed reviewer feedback</mark> by improving sourcing, formatting, and neutrality.|2=from [[Special:Diff/1365762152|this July 2026 edit]] to [[Draft:St. Augustine's Day School, Barrackpore]]}}

== Miscellaneous ==
=== Pronounced shift in writing style ===
A sudden shift in an editor's writing style, such as unexpectedly flawless grammar compared to their other communication (e.g., talk page comments versus text added), may indicate the use of AI. This is especially likely if that other writing predates November 2022. The reverse also applies: If a user has edits that predate LLM chatbots, and their writing style has remained consistent between those older edits and their current ones (e.g., frequent use of boldface, list formatting, etc.), that suggests the newer edits are less likely to be AI.

{{anchor|Sudden shift in English variety use}}A mismatch of user location, national ties of the topic to a variety of English, and the variety of English used may indicate the use of AI tools. A human writer from India writing about an Indian university would probably not use American English; however, several LLMs use American English by default unless prompted otherwise.<ref name="Ju et al." />

Note that non-native English speakers also tend to mix up English varieties, and many writers use more formal prose in certain venues as a form of [[code switching]] (although that doesn't rule out writers doing that code switching with AI). These signs should raise suspicion only if there is a dramatic, not easily explainable shift in an editor's writing style.

More subtly, if an editor has used AI for several years, the writing style of their edits will often change in parallel with contemporaneous AI tools: their 2023 edits will resemble 2023 LLM output, their 2025 edits will resemble 2025 LLM output, and so on.

=== "Submission statements" in AfC drafts ===
This one is specific to drafts submitted by [[WP:AFC|Articles for Creation]]. At least one LLM tends to insert "submission statements" supposedly intended for reviewers that supposedly explain why the subject is notable and why the draft meets Wikipedia guidelines. Of course, [[WP:BOOMERANG|all this actually does is]] let reviewers know that the draft is LLM-generated, and should be declined or speedily deleted without a second thought.

{{blockquote|Reviewer note (for AfC): This draft is a neutral and well-sourced biography of Portuguese public manager Jorge Patrão. All references are from independent, reliable sources (Público, Diário de Notícias, Jornal de Negócios, RTP, O Interior, Agência Lusa) covering his public career and cultural activity. It meets WP:RS and WP:BLP standards and demonstrates clear notability per WP:NBIO through: – Presidency of Serra da Estrela Tourism Region (1998–2013); – Presidency of Parkurbis – Covilhã Science and Technology Park; – Founding role in Rede de Judiarias de Portugal (member of the Council of Europe’s European Routes of Jewish Heritage); – Authorship of the book "1677 – A Fábrica d’El-Rei"; – Founder/curator of the Beatriz de Luna Art Collection (Old Master focus). There is also a Portuguese version of this article at pt.wikipedia.org/wiki/Jorge_Patrão. Thank you for your review. -->|From [[Special:Diff/1316087104|this October 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Jorge Patrão|Draft:Jorge Patrão]] (all the inevitable formatting errors are present in the original)}}

=== Pre-placed maintenance templates ===
{{shortcut|WP:AIDECLINE}}
Occasionally a new editor creates a draft that includes an [[WP:AFC|AFC]] review template already set to "declined". The template is also devoid of content with no reviewer reasoning given. The LLM apparently offers to add an AFC submission template to the draft, and then provides something like {{tlx|AfC submission|d}}, in which the "d" parameter pre-declines the draft by substituting {{tl|AfC submission/declined}}. The draft's contribution history reveals that this template was inserted at some point by the draft's creator. Invariably the creator then asks on [[Wikipedia:WikiProject Articles for creation/Help desk]] or one of the other help pages why the draft was declined with no feedback. The presence of a content-free "submission declined" header is a '''strong''' indicator that the draft was LLM-generated.

LLMs have been known to create pages that already have maintenance templates that shouldn't plausibly be there, including maintenance tags and incorrect [[WP:protection|protection]] templates.

{{blockquote|
<syntaxhighlight lang="wikitext">
{{Short description|French inventor and engineer (1861–1942)}}
{{pp|small=yes}}{{Use American English|date=September 2022}}
{{Use mdy dates|date=February 2025}}
</syntaxhighlight>
|From [[Special:Diff/1278033935|this revision]] to [[Wikipedia:Signs of AI writing/Examples/Émile Dufresne|Émile Dufresne]]}}

'''Links to searches'''
* {{plain link|url=https://en.wikipedia.org/wiki/Special:Search?search=%22you+declined+your%22&prefix=Wikipedia%3AWikiProject+Articles+for+creation%2FHelp+desk%2FArchives&fulltext=Search+the+help+desk+archives&fulltext=Search&ns0=1 "you declined your"}}
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22you+declined+it+yourself%22&prefix=Wikipedia%3AWikiProject+Articles+for+creation%2FHelp+desk%2FArchives&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 "you declined it yourself"}}
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22put+a+decline%22&prefix=Wikipedia%3AWikiProject+Articles+for+creation%2FHelp+desk%2FArchives&title=Special%3ASearch&profile=advanced&fulltext=1&ns0=1 "put a decline"}}

=== Canned user pages ===
{{shortcut|WP:AIUSERPAGE}}
{{main|Wikipedia:Canned user pages}}
Some AI-generated user pages follow a certain format and often contain [[WP:AILIST|inline-header vertical lists]] and section headings with titles like {{xt|Welcome To My User Page!}}, {{xt|About Me}}, {{xt|My Interests}}, and {{xt|Let's Connect!}}. They may also contain [[WP:AIEMOJI|emoji]] and [[WP:AIBOLD|bold text]]—or attempts at bold text with [[WP:MARKDOWN|Markdown]], which is typically the strongest giveaway that the content may have been generated by an LLM.

'''Examples'''
{{blockquote|
{{fake section|level=2|✨ About Me}}
* 🖊️ I enjoy writing about Indian cinema, culture, and history.
* 📚 I ensure accuracy by citing reliable sources.
* 🔧 I work on improving Wikipedia pages through editing and formatting.

{{fake section|level=2|🏆 My Contributions}}
* Created and improved '''20+ Wikipedia articles'''
* Fixed formatting, citations, and grammar issues
* Engaged in discussions to enhance Wikipedia content

{{fake section|level=2|💬 Let's Connect!}}
Feel free to leave a message on my **[[User talk:Arumobileworld|Talk Page]]** if you have any suggestions, questions, or would like to collaborate.

'''Happy Editing! 🚀'''
|From [[Special:Diff/1278940176|this March 2025 revision]] to a user page}}

'''Links to searches'''
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22About+Me%22+%22Let%27s+Connect%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns2=1 "About Me" "Let's Connect"}}
* {{plain link|url=https://en.wikipedia.org/w/index.php?search=%22About+Me%22+%22Let%27s+Collaborate%22&title=Special%3ASearch&profile=advanced&fulltext=1&ns2=1 "About Me" "Let's Collaborate"}}

=== Permissions gaming ===
[[WP:PGAME|Permissions gaming]] is a form of disruptive editing where someone makes many benign-seeming but unconstructive edits, often on disparate topics or in quick succession, until their edit count is high enough to raise their [[Wikipedia:User access levels|user access level]], allowing them to pursue their real goal of adding spam, vandalism, or contentious content.

Because AI chatbots are good at generating a lot of benign-looking content very quickly, people who game permissions after 2023 often do so with throwaway AI rewrites or additions to dozens of unrelated articles. If no one goes back and cleans up their edits, the result is a large swath of undetected and unreviewed AI content.

Note: This sign should only be used in one direction. Someone rapidly adding a lot of AI-generated text is ''not'' necessarily permissions gaming and should not be accused of it barring other evidence. However, if someone ''is'' found or reasonably suspected to be permissions gaming, and has done so by rapidly adding or changing a lot of text, those edits may be AI.

===Differences between LLMs===
Each model and version of AI chatbots have a distinctive way of writing ([[idiolect]]),<ref name="rud">{{cite journal |last1=Rudnicka |first1=Karolina |date=9 July 2025 |title=Each AI chatbot has its own, distinctive writing style—just as humans do |url=https://www.scientificamerican.com/article/chatgpt-and-gemini-ai-have-uniquely-different-writing-styles |journal=Scientific American |access-date=18 January 2026}}</ref><ref name="sun">{{cite web |last1=Sun |first1=Mingjie |last2=Yin |first2=Yida |first3=Zhiqiu |last3=Xu |first4=J. Zico |last4=Koller |first5=Zhuang |last5=Liu |title=Idiosyncrasies in Large Language Models |url=https://arxiv.org/abs/2502.12150v2 |access-date=16 April 2026}}</ref>, and what is typical for GPT-5 is not necessarily characteristic of GPT-4 or Gemini.

For example, text from ChatGPT (circa GPT-4o-2024-08-06) and Grok (Grok-Beta, as of late 2024/early 2025) exhibit characteristics that Gemini (1-5 Pro) and Claude (3.5-Sonnet) do not:
* [[WP:AILEGACY|focusing on broader context]] is more characteristic of ChatGPT and Grok than Gemini and Claude.<ref name="sun" />
* Gemini and Claude responses tend to be more concise than responses from ChatGPT and Grok.{{efn|This can be seen in articles on Grokipedia, which are extremely long.}}<ref name="sun" />

Though it's impossible to know for sure and there are many confounding variables, ChatGPT is likely the most widely used chatbot for Wikipedia edits.<ref name="zhou">{{cite web |last1=Zhou |first1=Moyan |last2=Cho |first2=Soobin |last3=Terveen |first3=Loren |title=LLMs in Wikipedia: Investigating How LLMs Impact Participation in Knowledge Communities |url=https://arxiv.org/abs/2509.07819 |website=arxiv |access-date=30 June 2026}}</ref>

== Signs of human writing ==

=== Age of text relative to ChatGPT launch ===
ChatGPT was launched to the public on November 30, 2022. Although OpenAI had similarly powerful LLMs before then, they were paid services and not easily accessible or known to lay people. Thus, if an edit was made '''before November 30, 2022''', AI use can be safely ruled out for the corresponding text. While some older writing displays some of the AI signs given in this list, and may even convincingly appear to have been AI-generated, the vastness of Wikipedia allows for these coincidences.
<!--
Some beta users of OpenAI, specifically before safety gates were enacted on raw OpenAI calls, were part of a program for startups that gave them early access with an appreciable amount of tokens to spend. These users would likely be more experimental and interact with publicly-editable content for [[public relations|reputation-cleansing]] or other purposes, so the date could be set back toward mid-2021 as a [[ballpark estimate]]. -->

=== Ability to explain one's own editorial choices ===
Editors should be able to explain why they made an edit or mistake. For example, if an editor inserts a URL that appears fabricated, you can ask how the mix-up occurred instead of jumping to conclusions. If they can supply the correct link and explain it as a human error (perhaps a typo), or share the relevant passage from the real source, that points to an ordinary human error.

=== Syntax ===
LLMs writing or editing Wikipedia articles will attempt, by default, to produce text in what it considers to be "formal, neutral, encyclopedic tone." This manifests as AI-generated text avoiding certain syntactic constructions that are both common in human writing and often perfectly acceptable per the [[Wikipedia:Manual of Style|Manual of Style]]--and in some cases, even preferred by it.

Specifically, the following have been empirically observed, over 25 years of Wikipedia writing, to be more common in Wikipedia articles written by humans than in AI-generated text:

* Simple is/has phrases,<ref name="geng2"/> such as ''there is a'', ''it has a''.
* Words with complex, stiff or euphemistic synonyms, such as ''wrote'' (versus ''authored''), ''moved'' (versus ''relocated''), ''used'' (versus ''utilized''), ''tried'' (versus ''attempted''), ''died'' (versus ''passed away'').
* Superlative or definitive statements, such as ''one of the best'', ''is the only'', ''was the first''
* Hedging qualifiers and intensifiers,<ref name="reinhart">{{cite web |last1=Reinhart |first1=Alex |last2=Markey |first2=Ben |last3=Laudenbach |first3=Michael |last4=Brown |first4=David West |title=Do LLMs write like humans? Variation in grammatical and 4 rhetorical styles |url=https://www.pnas.org/doi/10.1073/pnas.2422455122#supplementary-materials |website=pnas.org |access-date=6 June 2026}}</ref> such as ''very'', ''perhaps'', ''tends to''.
* Isolated wordy constructions such as ''as a result of'', ''in order to'', ''all of the'', ''a part of'', or ''the fact that''.

== Ineffective indicators ==
False accusations of AI use can [[Wikipedia:BITE|drive away new editors]] and foster an atmosphere of suspicion. Before claiming AI was used, consider whether the [[Dunning–Kruger effect]] or [[confirmation bias]] may be clouding your judgement. Detecting LLM texts on the basis of style alone is ''not'' as easy as it seems, see [[WP:AIDETECTIVE]] in this page. Here are several somewhat commonly used indicators that are ineffective in LLM detection{{em dash}}and may even indicate the opposite.

* '''Perfect grammar'''{{snd}}While modern LLMs are known for high grammatical proficiency, many editors are also skilled writers or come from professional writing backgrounds. (See also [[Wikipedia:Signs of AI writing#Sudden shift in English variety use|§ Sudden shift in English variety use]].)
* '''Combination of casual and formal registers, or language that sounds both "clinical" and "emotional"'''{{snd}}This may indicate the casual writing of a person in a technical field, such as computer science. It may also indicate youth, a preference for mixed registers, playfulness, or neurodivergence. In the case of a wiki, it may simply be the result of multiple editors adding to a page.
* '''"Bland" or "robotic" prose'''{{snd}}LLM output has specific traits, as detailed above, and it skews positive and verbose by default. While these tendencies are formulaic, they may not scan as "robotic" to those unfamiliar with AI writing.<ref name="jalt">{{cite journal |last1=Murray |first1=Nathan |last2=Tersigni |first2=Elisa |title=Can instructors detect AI-generated papers? Postsecondary writing instructor knowledge and perceptions of AI |journal=Journal of Applied Learning & Teaching |volume=7 |issue=2 |date=21 July 2024 |issn=2591-801X |doi=10.37074/jalt.2024.7.2.12 |url=https://journals.sfu.ca/jalt/index.php/jalt/article/view/1895 |access-date=21 November 2025}}</ref>
* '''"Fancy", "academic", or "formal" prose'''{{snd}}While LLMs disproportionately favor certain words and phrases, many of which are longer and have more difficult [[readability]] scores than some of their synonyms, these are ''specific words''. The correlation does not extend to all formal, academic, or "fancy"-sounding prose.<ref name="Russell" />
* '''Transition words (in isolation)'''{{snd}}Older AI text tended to formulaically overuse certain [[Transition (linguistics)|transitions]] like ''Additionally,'' ''Consequently,'' and ''Notably,'' often to begin sentences. However, only a few transition words and phrases are known to be overused by AI in this way. This pattern also has precedence in essay-like writing by humans and is accepted by many style guides, so this is not a strong tell.
* '''Unsourced content'''{{snd}}[[:Category:All articles with unsourced statements|More than 570,000 articles]] are tagged as needing citations, and most of them predate LLMs. Meanwhile, since modern LLM chatbots can search the web and view sources a user provides to it, citations are fairly common now in AI-generated text. This does not mean they are ''accurate'' citations, but they are there.
* '''Bizarre [[Help:Wikitext|wikitext]]'''{{snd}}While LLMs may hallucinate templates or generate wikitext code with invalid syntax for reasons explained in {{slink||Use of Markdown}}, they are not likely to generate content with certain random-seeming, "inexplicable" errors and artifacts (excluding the ones listed here in {{slink||Markup}}). Bizarrely placed [[HTML tags]] like <nowiki><span> are more indicative of poorly programmed browser extensions or a known bug with Wikipedia's content translation tool (</nowiki>{{Phabricator|T113137}}). Misplaced syntax like {{Code|''Catch-22 i''s a satirical novel.}} (rendered as "''Catch-22 i''s a satirical novel.") are more indicative of mistakes in [[Wikipedia:VisualEditor|VisualEditor]], where such errors are harder to notice than in [[Wikipedia:Source editing|source editing]].
* '''Correct wikitext'''{{snd}} Especially if the person is using the visual editor or has found the [[Help:Show preview|Preview]] button, getting the formatting correct, even for complex templates, is normal.

== Historical indicators ==
The following indicators were common in text generated by older AI models, but are much less frequent in newer models. They may still be useful for finding older undetected AI-generated edits. Dates are approximate.

===Didactic disclaimers (November 2022–2024) ===
{{shortcut|WP:DIDACTIC}}
{{For|non-AI-specific guidance about this|Wikipedia:Manual of Style/Words to watch#Editorializing}}
{{tmbox|image=none|text=Words to watch: {{strong|''it's important/critical/crucial to note/remember/consider'', ''worth noting'', ''may vary''...}}}}
Older LLMs (~2023) often added disclaimers about topics being "important to note".<ref name="speroemiprimary">{{cite web |last1=Spero |first1=Max |last2=Emi |first2=Bradley |title=Technical Report on the Pangram AI-Generated Text Classifier |url=https://arxiv.org/abs/2402.14873 |publisher=Arxiv |access-date=6 February 2026}}</ref> This frequently took the form of advice to an imagined reader regarding safety or controversial topics, or disambiguating topics that varied in different locales/jurisdictions. Several such disclaimers appear in OpenAI's GPT-4 system card as examples of "partial refusals".<ref name="openaicdn">{{cite web |title=GPT-4 System Card |url=https://cdn.openai.com/papers/gpt-4-system-card.pdf |website=OpenAI |access-date=16 December 2025}}</ref>

'''Examples'''
{{blockquote|The emergence of these informal groups reflects a growing recognition of the interconnected nature of urban issues and the potential for ANCs to play a role in shaping citywide policies. {{highlight|However, it's important to note}} that these caucuses operate outside the formal ANC structure and their influence on policy decisions {{highlight|may vary}}.|From [[Special:Diff/1265416814|this 2024 revision]] to [[Advisory Neighborhood Commission]]}}

{{blockquote|{{highlight|It is crucial to differentiate}} the independent AI research company based in Yerevan, Armenia, which is the subject of this report, from these unrelated organizations {{highlight|to prevent confusion}}.|From [[Special:Diff/1292938129|this 2025 revision]] to [[Wikipedia:Signs of AI writing/Examples/Robi Labs|Draft:Robi Labs]]}}

{{blockquote|{{highlight|It's important to remember}} that what's free in one country might not be free in another, so always check before you use something.|From [https://gitlab.wikimedia.org/repos/web/web-experiments-extension/-/commit/55fdbbb3decdc9b95ae0ef00e98b1108ddc3a498.diff Wikimedia's LLM-generated Simple Summary] of [[Public domain]]}}

===Section summaries===
{{Shortcut|WP:CONCLUSION|WP:INCONCLUSION}}
{{tmbox|image=none|text=Words to watch: {{strong|''In summary'', ''In conclusion'', ''Overall''&nbsp;...}}}}
When generating longer outputs (such as when told to "write an article"), older LLMs often added sections titled "Conclusion" or similar, and often ended paragraphs or sections by summarizing and restating its core idea.<ref name="Ju et al.">{{cite conference |last1=Ju |first1=Da |last2=Blix |first2=Hagen |last3=Williams |first3=Adina |title=Domain Regeneration: How well do LLMs match syntactic properties of text domains? |conference=Findings of the Association for Computational Linguistics: ACL 2025 |pages=2367–2388 |publisher=[[Association for Computational Linguistics]] |location=Vienna, Austria |date=2025 |doi=10.18653/v1/2025.findings-acl.120 |arxiv=2505.07784 |url=https://aclanthology.org/2025.findings-acl.120 |access-date=October 4, 2025 |via=[[ACL Anthology]] |archive-date=August 15, 2025 |archive-url=https://web.archive.org/web/20250815014117/https://aclanthology.org/2025.findings-acl.120/ |url-status=live }}</ref>

'''Examples'''
{{collapse top|From {{diff||1188230584|label=this 2023 revision}} in [[Nurse scientist]]}}
{{highlight|In summary}}, the educational and training trajectory for nurse scientists typically involves a progression from a master's degree in nursing to a Doctor of Philosophy in Nursing, followed by postdoctoral training in nursing research. This structured pathway ensures that nurse scientists acquire the necessary knowledge and skills to engage in rigorous research and contribute meaningfully to the advancement of nursing science.
{{collapse bottom}}

{{collapse top|From [[Talk:Eric Dick (lawyer)/Archive 1#c-Scott free0011-20240824022800-Bjan Anders-20240822031900|all]] [[Talk:Eric Dick (lawyer)#c-99.165.93.115-20240820214600-HCDE Tenure|of]] [[Talk:Eric Dick (lawyer)#c-Scott free0011-20240822005600-HCDE Tenure|these]] [[Talk:Eric Dick (lawyer)#c-Scott free0011-20240826231000-HCDE Tenure|August]] [[Talk:Eric Dick (lawyer)#c-Scott free0011-20240829040000-HCDE Tenure|2024]] [[Talk:Eric Dick (lawyer)#c-Scott free0011-20240830004100-HCDE Tenure|comments]] and [[Talk:Eric Dick (lawyer)#c-Scott free0011-20240904234400-HCDE Tenure|this September 2024 comment]] at [[Talk:Eric Dick (lawyer)]]}}
{{highlight|In summary,}} the current edits to the article are consistent with Wikipedia’s guidelines and are well-supported by reliable sources, including LinkedIn when used appropriately. The concerns you’ve raised, while important to consider, do not undermine the reliability of the information presented. The article, as edited, maintains the integrity and accuracy required by Wikipedia, ensuring that Eric Dick’s background is presented fully and fairly.
----
{{highlight|In summary,}} I believe the detailed coverage of Eric Dick’s involvement with HCDE is appropriate and valuable for readers. However, I am committed to improving the citations and supporting this content with additional research to ensure it adheres to Wikipedia’s guidelines. Please feel free to share any additional thoughts you might have.
----
{{highlight|Conclusion}}

{{highlight|In conclusion,}} while the concern about undue focus on Eric Dick's involvement with HCDE is valid, the solution should not be to simply cut large sections of content without proper research and verification. Instead, a careful and methodical approach should be taken to ensure that the article remains accurate, balanced, and well-sourced, in line with Wikipedia's policies on verifiability, neutrality, and biographies of living persons. Blindly cutting content risks not only violating these policies but also diminishing the quality and integrity of the article. Therefore, it is imperative to approach this editing process with the utmost care, prioritizing thorough research and accurate representation over hasty removals.
----
{{highlight|Conclusion:}} I’m committed to ensuring that all content in the article meets Wikipedia’s standards for reliability and neutrality. However, this requires a collaborative effort. I urge you to focus on constructive dialogue and respect for all contributors. Let’s work together to strengthen the article rather than engage in unnecessary conflict.
----
{{highlight|Conclusion:}}

Your current approach to editing and discussion, characterized by dismissive language, unfounded accusations, and a refusal to engage constructively, may potentially violate Wikipedia’s Civility policy and undermine the collaborative nature of the platform. I strongly urge you to reconsider how you interact with fellow editors. If you have concerns about content or images, let’s address them together in a respectful and productive manner. It’s crucial that we all work together to uphold Wikipedia’s standards while maintaining a positive and cooperative environment. Please try being nice to people for a change.
----
{{highlight|In conclusion,}} I am here to collaborate and work together to improve the article. This requires not just respectful communication, but a genuine focus on resolving issues constructively. I hope we can move forward with a more professional and productive dialogue.
----
{{highlight|In summary,}} I have consistently proposed well-sourced edits and have made clear my willingness to modify the content based on further discussion and research. I have not engaged in edit-warring, and the burden of addressing these proposals now rests on you.
{{collapse bottom}}

===Prompt refusal===
{{tmbox|image=none|text=Words to watch: {{strong|''as an AI language model'', ''as a large language model'', ''I cannot offer medical advice, but I can...'', ''I'm sorry''&nbsp;...}} }}
In the past, AI chatbots occasionally declined to answer prompts as written, usually with apologies and reminders that they are AI language models. Attempting to be helpful, chatbots often gave suggestions or answers to alternative, similar requests. Outright refusals have become increasingly rare.

'''Examples'''
{{blockquote|
As an AI language model, I can't directly add content to Wikipedia for you, but I can help you draft your bibliography.
|From [[Special:Diff/1221340799|this 2024 revision]] to [[Parmiter's Almshouse & Pension Charity]]}}

=== Abrupt cut offs ===
AI tools used to abruptly stop generating content if an excessive number of tokens had been used for a single response, and further responses required the user to select "continue generating", at least in the case of ChatGPT.

This method is not foolproof, as a malformed copy/paste from one's local computer can also cause this. It may also indicate a [[Project:Copyvio|copyright violation]] rather than the use of an LLM.

===Outdated ''access-date'' parameters===

In some AI-assisted text, citations may include an ''access-date'' by default, but the date can look unexpectedly old relative to when the edit was made (for example, an article created in December 2025 containing multiple citations with <code>|access-date=12 December 2024</code>). However, newer chatbots seldom produce this error, and older ''access-date'' values can occur legitimately (copied citations, offline work, batch moves/merges).

== See also ==
* The template {{tl|Looks AI-generated}}, which appears as {{looks AI-generated}}
* [[Wikipedia:Artificial intelligence resources]]
* [[Wikipedia:Artificial intelligence]]

== Notes ==
{{notelist}}

== References ==
{{reflist}}
 {{bots|deny=Citation bot}} <!-- sometimes AI makes mistakes with citations, we want those mistakes to be accurately represented here, not fixed by our maintenance bots -->

== Further reading ==
{{refbegin}}
* {{Cite web|last=Kriss|first=Sam|date=December 3, 2025|title=Why Does A.I. Write Like … That?|work=[[The New York Times Magazine]]|url=https://www.nytimes.com/2025/12/03/magazine/chatbot-writing-style.html|url-access=subscription|access-date=December 6, 2025}}
{{refend}}

== External links ==
* [https://canyoupasstheturingtest.com/ ''CanYouPasstheTuringTest.com'']
* [https://tropes.fyi/directory ''Tropes - AI Writing Pattern Directory'']

{{Wikipedia artificial intelligence}}
[[Category:Wikipedia and artificial intelligence]]
