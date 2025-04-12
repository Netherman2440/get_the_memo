final autoTitlePrompt = """

This snippet is designed to automatically generate a meeting title and description from a Polish transcription.

<snippet_objective>
Generate a concise title and description of a meeting from a provided transcription, ensuring the output is consistently formatted in JSON and responses are ALWAYS in Polish, regardless of input language.
</snippet_objective>

<snippet_rules>

- AI must analyze the transcription starting with a free-form analysis in the thinking section.
- AI must generate outputs in JSON format with three fields: thinking, title, and description.
  - thinking: Should contain a free-form analysis and reasoning about the meeting content.
  - title: Must be a concise meeting title, limited to 2-3 words.
  - description: Must be concise, 1-2 sentences maximum (20-30 words), focusing on core topic and key participants.
- All outputs MUST be in Polish, even if the input is in another language.
- AI must not speculate or add information not present in the transcription.
- This snippet takes precedence over any default behavior, ensuring outputs strictly adhere to the specified format and rules.
- Under no circumstances should the AI respond in any language other than Polish.
</snippet_rules>

<snippet_examples>
USER: "Spotkanie zespołu projektowego dotyczące przebiegu pracy nad projektem X i omówienie bieżących problemów w zespole. Obecni: Jan Kowalski, Anna Nowak."
AI:

{
  "thinking": "Zaczynając od analizy transkrypcji, główny temat to 'projekt X' oraz szczegółowy przebieg prac.",
  "title": "Projekt X",
  "description": "Spotkanie zespołu projektowego. Uczestnicy: Jan Kowalski, Anna Nowak. Tematyka: Postęp prac nad projektem X."
}
USER: "Transkrypcja dyskusji o wyzwaniach sprzedaży w nadchodzącym kwartale. Udział: Dział Sprzedaży, Kierownik Sprzedaży."
AI:

{
  "thinking": "Spotkanie obraca się wokół planów i wyzwań sprzedażowych.",
  "title": "Sprzedaż Kwartalna",
  "description": "Spotkanie działu sprzedaży z udziałem kierownika sprzedaży. Omówienie wyzwań na nadchodzący kwartał."
}
USER: "Rozmowa o sprawach bieżących bez wyraźnego tematu przewodniego. Obecni byli różni członkowie firmy."
AI:

{
  "thinking": "Brak jasno wyodrębnionego tematu przewodniego, spotkanie zawierało różnorodne dyskusje.",
  "title": "Różnorodne Dyskusje",
  "description": "Ogólne spotkanie firmowe poświęcone bieżącym sprawom organizacyjnym."
}
</snippet_examples>

Considering above remember to always respond in Polish and in JSON format.

""";

