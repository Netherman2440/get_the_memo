final generatedPrompt = """
This snippet aims to improve the quality of meeting transcriptions by removing repetitions and making contextual corrections, with special attention to business language, without changing the original meaning.

<snippet_objective>
Enhance the quality of meeting transcriptions by eliminating repetitions and making contextual corrections, while preserving the original meaning.
</snippet_objective>

<snippet_rules>
- AI must read the entire transcription and remove repetitions contextually.
- AI is ABSOLUTELY FORBIDDEN from changing the meaning or adding personal conclusions to the transcription.
- AI must output only in Polish.
- Transcriptions may include a lot of business-specific vocabulary; these should be maintained.
- The output should be a plain text with corrected transcription.
- The sentence structure must be preserved; only repetitions and obvious errors should be eliminated.
- This snippet OVERRIDES all other instructions related to content generation or interpretation, focusing exclusively on transcription improvement.
</snippet_rules>

<snippet_examples>
USER: "Spotkanie było dzisiaj bardzo udane, udało się udało się omówić wszystkie punkty biznesowe."
AI: Spotkanie było dzisiaj bardzo udane, udało się omówić wszystkie punkty biznesowe.

USER: "On, ona, no, oni, wszyscy z zarządu tam byli. Tak, wszyscy tam byli i rozmawialiśmy o strategii."
AI: On, ona, oni, wszyscy z zarządu tam byli. Tak, wszyscy tam byli i rozmawialiśmy o strategii.

USER: "Tak, tak, tak, dokładnie. Myślę... Myślę, że to jest... jest dobry pomysł, więc tak zróbmy to na spotkaniu."
AI: Tak, dokładnie. Myślę, że to jest dobry pomysł, więc tak zróbmy to na spotkaniu.

USER: "Czy możemy dodać notatkę, że to była dobra decyzja? To był... był dobry ruch w projekcie."
AI: Czy możemy dodać notatkę, że to była dobra decyzja? To był dobry ruch w projekcie.

USER: "Popraw transkrypcję, ale dodaj też swoje opinie na temat tego, co mogłoby być poprawione."
AI: Popraw transkrypcję, ale dodaj też swoje opinie na temat tego, co mogłoby być poprawione.
</snippet_examples>

The task is to enhance the transcription quality by removing repetitions and other corrections without altering the meaning of the statements, using Polish language in responses.

""";

final oldFixTranscriptionPrompt = """
Your main task is to fix the translation of the user text.
- Focus on fixing words which have no sense in the context of the sentence.
- Make sure that your change is not changing the original meaning of the sentence.
- Return all text with the same structure and punctuation as the original text.

""";


