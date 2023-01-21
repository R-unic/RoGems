require "parser/current"
# opt-in to most recent AST format:
Parser::Builders::Default.emit_lambda              = true
Parser::Builders::Default.emit_procarg0            = true
Parser::Builders::Default.emit_encoding            = true
Parser::Builders::Default.emit_index               = true
Parser::Builders::Default.emit_arg_inside_procarg0 = true
Parser::Builders::Default.emit_forward_arg         = true
Parser::Builders::Default.emit_kwargs              = true
Parser::Builders::Default.emit_match_pattern       = true

class CodeGenerator
    attr_reader :output

    def initialize(source)
        @source = source
        @output = ""
        @block = 0
        @line = 0
    end

    def generate()
        root_node = Parser::CurrentRuby.parse(@source)
        self.walk_ast(root_node)
        @output
    end

    def writeln(text)
        @output << text
        self.newline
    end

    def newline()
        @output << "\n"
        @output << "    " * @block
        @line += 1
    end

    def block()
        @output << "    " * @block
        @block += 1
    end

    def end()
        @block -= 1
        self.newline
        @output << "end"
    end

    def primary_privates(inited_privates)
        inited_privates.each { |var| self.instancevar_assign(var) }
    end

    def class_initializer(class_name, class_block, initializer = nil, parent = nil, readers = nil, writers = nil, accessors = nil, statics = nil)
        if initializer.nil? then
            self.writeln(")")
        end

        args = []
        if !initializer.nil? then
            args = initializer.children.map do |child|
                res = []
                if child.is_a?(Parser::AST::Node) && child.type == :super
                    vals = child.children.map do |a|
                        sym = a.type == :str ? self.quote_surround(a.children[0]) : a.children[0]
                    end
                    vals.each { |c| res.push(c) }
                    res
                end
            end
        end

        if args.length > 0 then
            self.newline
        end

        mixins = class_block.children.filter { |child| child.is_a?(Parser::AST::Node) && child.children[1] == :include }.map { |mixin| mixin.children[2].children[1].to_s }
        self.writeln("local include = {#{mixins.join(", ")}}")
        base_table = parent.nil? ? "{}" : "#{parent.children[1]}.new(#{args.compact.join(", ")})"
        self.writeln("local idxMeta = setmetatable(#{class_name}, { __index = #{base_table} })")

        @output << "for _, mixin in pairs(include) do"
        @block -= 1
        self.newline
        @block += 1
        self.block
        @output << "for k, v in pairs(mixin) do"
        @block -= 2
        self.newline
        @block += 2
        self.block
        @output << "idxMeta[k] = v"
        self.end
        self.end
        self.newline


        self.writeln("local self = setmetatable({}, { __index = idxMeta })")
        self.writeln("self.attr_accessor = setmetatable({}, { __index = idxMeta.attr_accessor or {} })")
        self.writeln("self.attr_reader = setmetatable({}, { __index = idxMeta.attr_reader or {} })")
        self.writeln("self.attr_writer = setmetatable({}, { __index = idxMeta.attr_writer or {} })")
        self.writeln("self.writable = {}")
        self.writeln("self.private = {}")
        self.newline

        if !initializer.nil? then
            initializer_block = initializer.children[2]
            self.walk_ast(initializer_block, readers, writers, accessors, statics)
        end

        self.newline
        self.newline
        self.writeln("return setmetatable(self, {")
        @block -= 1
        self.block
        self.writeln("__index = function(t, k)")
        self.block
        self.writeln("if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then")
        @block -= 1
        self.block
        @block += 2
        output << "return nil"
        self.end
        self.newline
        output << "return self.attr_reader[k] or self.attr_accessor[k] or #{class_name}[k]"
        self.end
        self.writeln(",")

        self.writeln("__newindex = function(t, k, v)")
        @block -= 2
        self.block
        self.writeln("if t.writable[k] or self.writable[k] or idxMeta.writable[k] then")
        @block += 1
        self.block
        @block -= 1
        self.writeln("if self.attr_writer[k] then")
        self.block
        @block += 1
        self.writeln("self.attr_writer[k] = v")
        @output << "elseif self.attr_accessor[k] then"
        @block += 1
        self.newline
        @output << "self.attr_accessor[k] = v"
        self.end
        @block -= 1
        self.newline

        @output << "else"
        @block += 1
        self.newline
        @output << "error(\"Attempt to write to un-writable attribute '\"..k..\"'\")"
        self.end
        self.end
        @block -= 1

        self.newline
        output << "})"

        self.end
    end

    def get_class_initer_def(block)
        initializer = block.children.select {|def_node| def_node.children[0] == :initialize}[0]
        if initializer && initializer.children[0] == :initialize then
            initializer_args = initializer.children[1]
            arg_list = initializer_args.children.map { |arg| arg.children[0] }.join(", ")
            @output << "#{arg_list})"
        end
        initializer
    end

    def class_def(node)
        class_name = node.children[0].children[1].to_s
        parent = node.children[1]
        block = node.children[2]

        @output << "--classdef"
        self.newline
        @output << "local #{class_name} = {} do"
        self.newline
        @block += 1
        self.block
        @block -= 2
        self.block
        @block += 1

        @output << "function #{class_name}.new("

        added_initializer = false
        if !block.nil? then
            if block.type != :begin && !added_initializer then
                self.class_initializer(class_name, block, nil, parent)
                added_initializer = true
            end
            case block.type
            when :begin
                if !added_initializer then
                    readers = block.children.filter { |stmt| stmt.class == Parser::AST::Node && stmt.children[1] == :attr_reader }.map { |stmt| stmt.children[2].children[0].to_s }
                    writers = block.children.filter { |stmt| stmt.class == Parser::AST::Node && stmt.children[1] == :attr_writer }.map { |stmt| stmt.children[2].children[0].to_s }
                    accessors = block.children.filter { |stmt| stmt.class == Parser::AST::Node && stmt.children[1] == :attr_accessor }
                    inited_privates = block.children.filter { |stmt| stmt.class == Parser::AST::Node && stmt.type == :ivasgn }
                    statics = block.children.filter { |stmt| stmt.class == Parser::AST::Node && stmt.type == :cvasgn }
                    initializer = self.get_class_initer_def(block)

                    self.class_initializer(class_name, block, initializer, parent, readers, writers, accessors, statics)
                    self.primary_privates(inited_privates)
                    added_initializer = true

                    self.walk_ast(block, readers, writers, accessors, statics, class_name)
                end
            when :send

            when :ivasgn

            end
        else
            self.class_initializer(class_name, block, nil, parent)
        end
        self.end
    end

    def module_def(node)
        module_name = node.children[0].children[1].to_s
        block = node.children[1]

        self.writeln("--moduledef")
        self.writeln("local #{module_name} = {} do")
        @block += 1
        self.block
        @block -= 1

        if !block.nil? then
            _, args, def_block = *block.children
            new_block = block.updated(nil, ["#{module_name}:#{block.children[0].to_s}".to_sym, args, def_block])
            self.walk_ast(new_block)
        end

        self.end
    end

    def quote_surround(s)
        "\"#{s}\""
    end

    def instancevar_assign(node, location = nil)
        name_node, val_node = *node.children
        key = name_node.to_s.gsub("@", "")
        val = val_node.children[0].to_s
        if val_node.type == :str then
            val = self.quote_surround(val)
        end

        @output << "self." << (location || "private.") << "#{key} = #{val}"
        if location == "attr_accessor." || location == "attr_writer." then
            self.newline
            @output << "self.writable.#{key} = true"
        end
    end

    def multiple_assign(node)
        names_node, vals_node = *node.children

        nidx = 1
        added_keyword = false
        names_node.children.each do |name|
            if name.type == :lvasgn && !added_keyword then
                added_keyword = true
                @output << "local "
            end
            var_name = name.children[0].to_s
            @output << (name.type == :gvasgn ? var_name.gsub!("$", "") : var_name) << (nidx == names_node.children.length ? "" : ", ")
            nidx += 1
        end
        @output << " = "

        vidx = 1
        vals_node.children.each do |val|
            @output << val.children[0].to_s << (vidx == vals_node.children.length ? "" : ", ")
            vidx += 1
        end
    end

    def get_iv_location_name(var_name, readers, writers, accessors, statics)
        if !readers.nil? && readers.include?(var_name) then
            "attr_reader."
        elsif !writers.nil? && writers.include?(var_name) then
            "attr_writer."
        elsif !accessors.nil? && accessors.include?(var_name) then
            "attr_accessor."
        elsif !statics.nil? && statics.include?(var_name) then
            # class name (Animal)
            ""
        end
    end

    def check_operator(str)
        operators = %w(+ - * / % ** & | ^ > >= < <= == === != =~ !~ && ||)
        if operators.include?(str)
            " #{str} "
        else
            str
        end
    end

    def walk_ast(node, *extra_data)
        if node.is_a?(Parser::AST::Node) then
            case node.type
            when :float, :int # literals
                @output << node.children[0].to_s
            when :str
                content = node.children[0].to_s
                @output << self.quote_surround(content)
            when :send # operations
                if node.children[1] == :attr_accessor || node.children[1] == :attr_reader || node.children[1] == :attr_writer || node.children[1] == :include then return end

                dont_emit_function_check = extra_data[0]
                not_function = extra_data[1]
                is_assignment = node.children[1].to_s.include?("=")
                first_child = node.children[0]
                do_function_check = (dont_emit_function_check || false) == false && !is_assignment && first_child && first_child.type == :lvar
                if do_function_check then
                    current_line = @output.split("\n")[@line]
                    if current_line.nil? then
                        @output << "local _ = "
                    end
                    @output << "type("
                end
                idx = 1
                node.children.each do |child|
                    if child.is_a?(Parser::AST::Node) then
                        case child.type
                        when :send
                            self.walk_ast(child)
                        when :str
                            self.walk_ast(child)
                            @output << idx == node.children.length ? "" : ", "
                        when :lvar
                            @output << child.children[0].to_s.strip
                            if node.children[0].type == :lvar then
                                @output << (do_function_check || (not_function || false) == true || is_assignment ? "." : ":")
                            end
                        # when :cvar
                        when :ivar
                            var_name = child.children[0].to_s.gsub("@", "")
                            readers, writers, accessors, statics = *extra_data
                            readers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                            writers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                            accessors.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                            statics.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                            location = self.get_iv_location_name(var_name, readers, writers, accessors, statics) || "private."
                            @output << "self." << location << var_name
                        when :const
                            @output << child.children[1].to_s
                        else
                            var_name = child.children[0].to_s.strip
                            @output << var_name
                        end
                    elsif child == :puts then
                        @output << "print("
                    elsif child == :new then
                        @output << ".new("
                    else
                        sym = child.to_s
                        if sym.include?("=") then
                            sym = sym.gsub!("=", "") + " = "
                        end
                        @output << self.check_operator(sym)
                        if first_child && first_child.type == :lvar && !do_function_check && !not_function && !is_assignment then
                            args = [*node.children]
                            args.shift(2)
                            @output << "(#{args.join(", ")})"
                        end
                    end
                    idx += 1
                end
                if do_function_check then
                    @output << ") == \"function\" and "
                    self.walk_ast(node, true)
                    @output << " or "
                    self.walk_ast(node, true, true)
                end
                if node.children[1] == :puts || node.children[1] == :new then
                    @output << ")"
                end
            when :module # module defs
                self.module_def(node)
            when :class # class defs
                self.class_def(node)
            when :begin # blocks
                idx = 1
                node.children.each do |child|
                    if idx == node.children.length && child.type != :ivasgn && child.type != :class  && child.type != :module && child.type != :def && child.type != :puts && child.children[1] != :puts then
                        @output << "return "
                    end
                    if child.is_a?(Parser::AST::Node) then
                        self.walk_ast(child, *extra_data)
                    end
                    if idx != node.children.length then
                        self.newline
                    end
                    idx += 1
                end
            when :def # defs
                def_name = node.children[0]
                args = node.children[1].children
                arg_list = args.map { |arg| arg.children[0] }.join(", ")
                block = node.children[2]
                class_name = extra_data[4]
                if def_name == :initialize then return end
                self.writeln("function #{class_name.nil? ? "" : class_name + ":"}#{def_name.to_s}(#{arg_list})")
                self.block
                if !block.nil? then
                    self.walk_ast(block, *extra_data)
                end
                self.end
            when :masgn
                self.multiple_assign(node)
            when :lvasgn, :gvasgn # local var assignment
                name, val = *node.children
                @output << (node.type == :lvasgn ? "local " : "") << (node.type == :gvasgn ? name.gsub!("$", "") : name.to_s) << " = "
                if val.is_a?(Parser::AST::Node) then
                    self.walk_ast(val)
                else
                    @output << val.children[0].to_s
                end
            when :ivasgn
                var_name = node.children[0].to_s.gsub("@", "")
                readers, writers, accessors, statics = extra_data
                readers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                writers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                accessors.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                statics.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                location = self.get_iv_location_name(var_name, readers, writers, accessors, statics)
                self.instancevar_assign(node, location)
            else
                puts "unhandled ast node: #{node}"
            end
        elsif node.is_a?(Symbol) then
            @output << " #{node.to_s} "
        end
        @last_line = @line
    end
end
