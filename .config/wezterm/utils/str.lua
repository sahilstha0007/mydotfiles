local M = {}

---@param str string
---@param prefix string
---@return boolean
M.starts_with = function(str, prefix)
   return str:sub(1, #prefix) == prefix
end

---@param str string
---@param suffix string
---@return boolean
M.ends_with = function(str, suffix)
   return str:sub(-#suffix) == suffix
end

---Decode next UTF-8 codepoint starting at byte index `i` (pure Lua: compatible with LuaJIT & WezTerm Lua 5.4).
---@param s string
---@param i integer
---@return integer cp
---@return integer next_i
local function next_codepoint(s, i)
   local b1 = s:byte(i)
   if not b1 then
      return 0, i
   end
   if b1 < 0x80 then
      return b1, i + 1
   elseif b1 >= 0xC2 and b1 <= 0xDF then
      local b2 = s:byte(i + 1)
      if b2 and b2 >= 0x80 and b2 <= 0xBF then
         return (b1 - 0xC0) * 64 + (b2 - 0x80), i + 2
      end
   elseif b1 >= 0xE0 and b1 <= 0xEF then
      local b2, b3 = s:byte(i + 1, i + 2)
      if b2 and b3 and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF then
         return ((b1 - 0xE0) * 64 + (b2 - 0x80)) * 64 + (b3 - 0x80), i + 3
      end
   elseif b1 >= 0xF0 and b1 <= 0xF4 then
      local b2, b3, b4 = s:byte(i + 1, i + 3)
      if
         b2
         and b3
         and b4
         and b2 >= 0x80
         and b2 <= 0xBF
         and b3 >= 0x80
         and b3 <= 0xBF
         and b4 >= 0x80
         and b4 <= 0xBF
      then
         return (((b1 - 0xF0) * 64 + (b2 - 0x80)) * 64 + (b3 - 0x80)) * 64 + (b4 - 0x80), i + 4
      end
   end
   return b1, i + 1
end

---@param cp integer
---@return boolean
local function is_zero_width(cp)
   return cp < 0x20
      or (cp >= 0x7F and cp <= 0x9F)
      or (cp >= 0x0300 and cp <= 0x036F)
      or (cp >= 0x1AB0 and cp <= 0x1AFF)
      or (cp >= 0x1DC0 and cp <= 0x1DFF)
      or (cp >= 0x200B and cp <= 0x200F)
      or (cp >= 0x202A and cp <= 0x202E)
      or (cp >= 0x2060 and cp <= 0x206F)
      or (cp >= 0xFE00 and cp <= 0xFE0F)
      or (cp >= 0xFE20 and cp <= 0xFE2F)
      or (cp >= 0x1F3FB and cp <= 0x1F3FF)
      or (cp >= 0xE0100 and cp <= 0xE01EF)
end

---@param cp integer
---@return boolean
local function is_wide_cp(cp)
   return (cp >= 0x1100 and cp <= 0x115F)
      or cp == 0x2329
      or cp == 0x232A
      or (cp >= 0x231A and cp <= 0x231B)
      or (cp >= 0x23E9 and cp <= 0x23F3)
      or (cp >= 0x23F8 and cp <= 0x23FA)
      or (cp >= 0x25FD and cp <= 0x25FE)
      or (cp >= 0x2600 and cp <= 0x27BF)
      or (cp >= 0x2B50 and cp <= 0x2B55)
      or (cp >= 0x2E80 and cp <= 0x303E)
      or (cp >= 0x3041 and cp <= 0x33FF)
      or (cp >= 0x3400 and cp <= 0x4DBF)
      or (cp >= 0x4E00 and cp <= 0x9FFF)
      or (cp >= 0xA000 and cp <= 0xA4CF)
      or (cp >= 0xA960 and cp <= 0xA97F)
      or (cp >= 0xAC00 and cp <= 0xD7A3)
      or (cp >= 0xF900 and cp <= 0xFAFF)
      or (cp >= 0xFE10 and cp <= 0xFE19)
      or (cp >= 0xFE30 and cp <= 0xFE6F)
      or (cp >= 0xFF01 and cp <= 0xFF60)
      or (cp >= 0xFFE0 and cp <= 0xFFE6)
      or (cp >= 0x1F000 and cp <= 0x1FAFF)
      or (cp >= 0x20000 and cp <= 0x3FFFD)
end

---@param cp integer
---@return integer
local function cp_width(cp)
   if is_zero_width(cp) then
      return 0
   end
   if is_wide_cp(cp) then
      return 2
   end
   return 1
end

---Split UTF-8 string into atomic grapheme clusters `{ text, width }`.
---Combining marks, variation selectors (including VS16 widening), skin tones,
---and ZWJ sequences stay attached to the base cluster so truncation never splits them.
---@param str string
---@return { text: string, width: integer }[]
M.utf8_graphemes = function(str)
   local clusters = {}
   local i, len = 1, #str
   local prev_was_zwj = false

   while i <= len do
      local cp, next_i = next_codepoint(str, i)
      local piece = str:sub(i, next_i - 1)
      local w = cp_width(cp)

      if prev_was_zwj and #clusters > 0 then
         clusters[#clusters].text = clusters[#clusters].text .. piece
         prev_was_zwj = false
      elseif w == 0 and #clusters > 0 then
         clusters[#clusters].text = clusters[#clusters].text .. piece
         if cp == 0xFE0F then
            clusters[#clusters].width = 2
         end
         prev_was_zwj = (cp == 0x200D)
      else
         clusters[#clusters + 1] = { text = piece, width = w }
         prev_was_zwj = (cp == 0x200D)
      end

      i = next_i
   end

   return clusters
end

---Display column width of UTF-8 string (wcwidth-aware for CJK & emoji).
---@param str string
---@return integer
M.display_width = function(str)
   local total = 0
   for _, g in ipairs(M.utf8_graphemes(str)) do
      total = total + g.width
   end
   return total
end

---Right-truncate UTF-8 string to at most `max_cols` display cells, appending `…`.
---@param str string
---@param max_cols integer
---@return string
M.truncate_right = function(str, max_cols)
   if max_cols <= 0 then
      return ''
   end
   local clusters = M.utf8_graphemes(str)
   local total = 0
   for _, g in ipairs(clusters) do
      total = total + g.width
   end
   if total <= max_cols then
      return str
   end
   if max_cols == 1 then
      return '…'
   end

   local budget = max_cols - 1 -- reserve 1 cell for '…'
   local out, used = {}, 0
   for _, g in ipairs(clusters) do
      if used + g.width > budget then
         break
      end
      out[#out + 1] = g.text
      used = used + g.width
   end
   out[#out + 1] = '…'
   return table.concat(out)
end

---Head-truncate UTF-8 string to at most `max_cols` display cells, prepending `…`.
---@param str string
---@param max_cols integer
---@return string
M.truncate_left = function(str, max_cols)
   if max_cols <= 0 then
      return ''
   end
   local clusters = M.utf8_graphemes(str)
   local total = 0
   for _, g in ipairs(clusters) do
      total = total + g.width
   end
   if total <= max_cols then
      return str
   end
   if max_cols == 1 then
      return '…'
   end

   local budget = max_cols - 1
   local kept, used = {}, 0
   for idx = #clusters, 1, -1 do
      local g = clusters[idx]
      if used + g.width > budget then
         break
      end
      kept[#kept + 1] = g.text
      used = used + g.width
   end
   local out = { '…' }
   for idx = #kept, 1, -1 do
      out[#out + 1] = kept[idx]
   end
   return table.concat(out)
end

---Middle/head-truncate filesystem path strings so basename & leading command survive.
---@param str string
---@param max_cols integer
---@return string
M.truncate_title = function(str, max_cols)
   if max_cols <= 0 then
      return ''
   end
   if M.display_width(str) <= max_cols then
      return str
   end
   if max_cols == 1 then
      return '…'
   end

   -- Detect an embedded filesystem path (e.g., '/very/long/.../file', '~/a/b/.../file',
   -- 'nvim /a/b/.../file', 'proj ~ /a/b/.../file').
   local head_ctx, path_part = str:match('^(.-%s)(~/.*)$')
   if not path_part then
      head_ctx, path_part = str:match('^(.-%s)(/.*)$')
   end
   if not path_part and (M.starts_with(str, '/') or M.starts_with(str, '~/')) then
      head_ctx, path_part = '', str
   end

   if path_part then
      local trimmed_path = path_part:gsub('/+$', '')
      local basename = trimmed_path:match('([^/]+)$')
      if basename and basename ~= '' and trimmed_path ~= basename then
         -- Extract leading root indicator ('/' or '~/') and parent segments
         local root_prefix = ''
         local rest = trimmed_path
         if M.starts_with(trimmed_path, '~/') then
            root_prefix = '~/'
            rest = trimmed_path:sub(3)
         elseif M.starts_with(trimmed_path, '/') then
            root_prefix = '/'
            rest = trimmed_path:sub(2)
         end

         local segs = {}
         for seg in rest:gmatch('[^/]+') do
            segs[#segs + 1] = seg
         end
         local tail = segs[#segs] or basename

         -- Keep leading root + first segment when space permits for true middle truncation
         local leading_seg = root_prefix
         if #segs >= 2 then
            local with_first = head_ctx .. root_prefix .. segs[1] .. '/…/' .. tail
            if M.display_width(with_first) <= max_cols then
               leading_seg = root_prefix .. segs[1] .. '/'
            end
         end

         -- Build extra right-hand parent directories as space permits while keeping '…/' + tail
         local kept_tail = tail
         local stop_idx = (#leading_seg > #root_prefix) and 3 or 2
         for idx = #segs - 1, stop_idx, -1 do
            local candidate_tail = segs[idx] .. '/' .. kept_tail
            local probe = head_ctx .. leading_seg .. '…/' .. candidate_tail
            if M.display_width(probe) <= max_cols then
               kept_tail = candidate_tail
            else
               break
            end
         end

         -- Try middle truncation preserving command/head_ctx + leading_seg + …/ + tail
         local middle = head_ctx .. leading_seg .. '…/' .. kept_tail
         if M.display_width(middle) <= max_cols then
            return middle
         end

         -- Drop root prefix if tight, keeping command + '…/' + tail
         local head_slash = head_ctx .. '…/' .. tail
         if M.display_width(head_slash) <= max_cols then
            return head_slash
         end

         -- Tight budget: preserve as much head_ctx (command) as possible + head-truncated tail
         local ctx_w = M.display_width(head_ctx)
         if head_ctx ~= '' and ctx_w > 0 and ctx_w <= max_cols - 3 then
            return head_ctx .. M.truncate_left('/' .. tail, max_cols - ctx_w)
         end

         return M.truncate_left('/' .. tail, max_cols)
      end
   end

   return M.truncate_right(str, max_cols)
end

return M
