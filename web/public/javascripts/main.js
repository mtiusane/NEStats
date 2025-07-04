document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll("#links .f__text, #menu .f__text").forEach(el => {
        el.replaceWith(Common.createEl("span", {}, "", Common.format_text(el.text)))
    });
});
