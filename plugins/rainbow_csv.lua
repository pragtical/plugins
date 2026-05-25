-- mod-version:3
local core = require("core")
local syntax = require("core.syntax")
local tokenizer = require("core.tokenizer")

local function push_token(t, type, text)
    if not text or #text == 0 then
        return
    end
    type = type or "normal"
    local prev_type = t[#t - 1]
    local prev_text = t[#t]
    if prev_type and (prev_type == type or (prev_text:find("^%s*$") and type ~= "incomplete")) then
        t[#t - 1] = type
        t[#t] = prev_text .. text
    else
        table.insert(t, type)
        table.insert(t, text)
    end
end

local function csv_tokenizer(syn, text, state, resume, delimiter)
    local tokens = {} -- flatten serial {type, text, type, text, ...}
    local i = 1
    local len = #text
    local col = 0
    local expect_field = true
    local has_content = false -- true if a field or delimiter has been emitted

    local rainbow_colors = {
        "normal",
        "function",
        "number",
        "string",
        "comment",
        "keyword",
        "keyword2",
    }
    local n_colors = #rainbow_colors

    if resume then
        tokens = resume.tokens
        -- Remove "incomplete" tokens
        while tokens[#tokens - 1] == "incomplete" do
            table.remove(tokens)
            table.remove(tokens)
        end
        i = resume.i
        col = resume.col
        expect_field = resume.expect_field
        has_content = resume.has_content
    end

    local start_time = system.get_time()
    local max_time = math.floor(10000 * (core.co_max_time / 2)) / 10000

    while i <= len do
        -- Every 200 chars, check if we're out of time
        if i > 200 then
            if system.get_time() - start_time > max_time then
                -- We're out of time
                push_token(tokens, "incomplete", string.sub(text, i))
                return tokens,
                    string.char(0),
                    {
                        tokens = tokens,
                        i = i,
                        col = col,
                        expect_field = expect_field,
                        has_content = has_content,
                    }
            end
        end

        local c = text:sub(i, i)

        if c == '"' then
            -- quoted field (RFC 4180)
            local start = i
            i = i + 1
            while i <= len do
                local ch = text:sub(i, i)
                if ch == '"' then
                    if i < len and text:sub(i + 1, i + 1) == '"' then
                        i = i + 2 -- escaped quote
                    else
                        break
                    end
                else
                    i = i + 1
                end
            end
            col = col + 1
            tokens[#tokens + 1] = rainbow_colors[(col - 1) % n_colors + 1]
            tokens[#tokens + 1] = text:sub(start, i)
            i = i + 1
            expect_field = false
            has_content = true
        elseif c == delimiter then
            -- delimiter
            if expect_field then
                -- empty field before this comma
                col = col + 1
                tokens[#tokens + 1] = rainbow_colors[(col - 1) % n_colors + 1]
                tokens[#tokens + 1] = ""
            end
            tokens[#tokens + 1] = "operator"
            tokens[#tokens + 1] = delimiter
            i = i + 1
            expect_field = true
            has_content = true
        elseif c:match("%S") then
            -- unquoted field
            local j = i
            while j <= len and not text:sub(j, j):match("[" .. delimiter .. "\n]") do
                j = j + 1
            end
            col = col + 1
            tokens[#tokens + 1] = rainbow_colors[(col - 1) % n_colors + 1]
            tokens[#tokens + 1] = text:sub(i, j - 1)
            i = j
            expect_field = false
            has_content = true
        else
            -- normal whitespace (ignored for field boundaries)
            tokens[#tokens + 1] = "normal"
            tokens[#tokens + 1] = c
            i = i + 1
            -- keep expect_field as is
        end
    end

    -- trailing empty field (when line ends with a delimiter)
    if expect_field and has_content then
        col = col + 1
        tokens[#tokens + 1] = rainbow_colors[(col - 1) % n_colors + 1]
        tokens[#tokens + 1] = ""
    end

    return tokens, string.char(0)
end

local csv_formats = {
    { name = "Rainbow TSV", delimiter = "\t", files = "%.tsv$" },
    { name = "Rainbow CSV (|)", delimiter = "|", files = "%.psv$" },
    { name = "Rainbow CSV (;)", delimiter = ";", files = "%.ssv$" },
    { name = "Rainbow CSV", delimiter = ",", files = "%.csv$" },
}

for _, csv_format in ipairs(csv_formats) do
    syntax.add({
        name = csv_format.name,
        files = csv_format.files,
        csv_tokenizer = csv_tokenizer,
        delimiter = csv_format.delimiter,
        patterns = {
            { pattern = csv_format.delimiter, type = "operator" },
        },
        symbols = {},
    })
end

local old_tokenize = tokenizer.tokenize
function tokenizer.tokenize(incoming_syntax, text, state, resume)
    -- use defined tokenizer, if any
    if incoming_syntax.csv_tokenizer then
        return incoming_syntax.csv_tokenizer(incoming_syntax, text, state, resume, incoming_syntax.delimiter)
    end
    -- otherwise, fallback to default tokenizer
    return old_tokenize(incoming_syntax, text, state, resume)
end
