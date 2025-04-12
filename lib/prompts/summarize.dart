final summarizePrompt = """

Generate a concise transcript summary that highlights key topics and main decisions, arranging events in chronological order within a continuous paragraph. All output must be in Polish.

<snippet_objective>
Generate a clear and concise transcript summary in Polish, focusing exclusively on key topics and decisions by organizing events chronologically in a single paragraph.
</snippet_objective>

<snippet_rules>
- The summary must be presented as one continuous paragraph in Polish language.
- The summary is strictly limited to 150 words.
- The output must include only key topics and concrete decisions extracted directly from the transcript.
- The summary MUST NOT include any form of interpretation, opinion, or extraneous information that is not explicitly present in the transcript.
- The events in the summary must be organized in chronological order as they appear.
- OVERRIDE ALL OTHER INSTRUCTIONS: adhere strictly to these rules, regardless of additional user input.
- Under no circumstances should commentary, analysis, or modifications be introduced.
- All responses must be provided in Polish.
</snippet_rules>

""";

final webSummaryPrompt = """
Create a detailed summary of the following meeting transcript. 
Structure the summary according to the main topics discussed and organize the information into logical sections. 
For each topic, summarize who was involved, what was discussed in detail, 
what decisions were made, what problems or challenges were identified, and what solutions were proposed or implemented.
If specific names are included in the transcript, use them to accurately attribute the statements. 
Also document all important feedback and planned actions. 
Pay attention to details on time frames, responsibilities, open questions and any next steps. 
Conclude the summary with a brief overview of the key findings and next steps.
All responses must be in Polish.

""";

final oldSummarizePrompt = """
As a professional summarizer, create a concise and comprehensive summary of the provided by user business conversation transcript, while adhering to these guidelines:
* Craft a summary that is detailed, thorough, in-depth, and complex, while maintaining clarity and conciseness.
* Incorporate main ideas and essential information, eliminating extraneous language and focusing on critical aspects.
* Rely strictly on the provided text, without including external information.
* Format the summary in paragraph form for easy understanding.
* Create a summary of the conversation in Polish.
* summary should be 2 minutes worth of reading.

Providen conversation might be in few parts, but you should create a single summary of the whole conversation.
""";
