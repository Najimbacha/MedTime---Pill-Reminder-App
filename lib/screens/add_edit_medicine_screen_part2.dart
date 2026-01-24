
  Widget _buildImagePicker(bool isDark) {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.add_a_photo_rounded,
                    size: 32,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
          ),
          if (_imagePath != null)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () {
                  setState(() => _imagePath = null);
                  HapticHelper.light();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? label,
    required bool isDark,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface1Dark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black26,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: icon != null 
              ? Icon(icon, color: isDark ? Colors.white38 : Colors.black38) 
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          isDense: true,
        ),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTypeAndColorSelector(bool isDark) {
    return Column(
      children: [
        _buildMedicineTypeSelector(isDark),
        const SizedBox(height: 16),
        _buildColorSelector(isDark),
      ],
    );
  }
