const form = document.querySelector("#note-form");
const input = document.querySelector("#note-text");
const list = document.querySelector("#notes-list");
const emptyState = document.querySelector("#empty-state");
const message = document.querySelector("#message");
const refreshButton = document.querySelector("#refresh-button");

async function loadNotes() {
    message.textContent = "";

    try {
        const response = await fetch("/api/notes");

        if (!response.ok) {
            throw new Error("Не удалось получить записи");
        }

        const notes = await response.json();
        renderNotes(notes);
    } catch (error) {
        message.textContent = error.message;
    }
}

function renderNotes(notes) {
    list.innerHTML = "";
    emptyState.hidden = notes.length > 0;

    for (const note of notes) {
        const item = document.createElement("li");
        item.className = "note";

        const text = document.createElement("span");
        text.className = "note-text";
        text.textContent = note.text;

        const meta = document.createElement("span");
        meta.className = "note-meta";
        meta.textContent = `#${note.id} · ${new Date(note.created_at).toLocaleString()}`;

        item.append(text, meta);
        list.appendChild(item);
    }
}

form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const text = input.value.trim();
    if (!text) {
        return;
    }

    message.textContent = "Сохраняем...";

    try {
        const response = await fetch("/api/notes", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ text }),
        });

        if (!response.ok) {
            throw new Error("Не удалось сохранить запись");
        }

        input.value = "";
        message.textContent = "Запись сохранена в PostgreSQL.";
        await loadNotes();
        input.focus();
    } catch (error) {
        message.textContent = error.message;
    }
});

refreshButton.addEventListener("click", loadNotes);

loadNotes();
