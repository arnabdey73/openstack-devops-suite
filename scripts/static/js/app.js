/**
 * 1-Click Application Onboarding Portal JavaScript
 */

// Global variables
let selectedTemplate = null;
let selectedFrameworks = [];
let currentStep = 1;
let deploymentData = {};
let csrfToken = '';

// DOM elements
const templatesContainer = document.getElementById('templatesContainer');
const step1Card = document.getElementById('step1Card');
const step2Card = document.getElementById('step2Card');
const step3Card = document.getElementById('step3Card');
const step4Card = document.getElementById('step4Card');
const frameworkSelect = document.getElementById('framework');
const appNameInput = document.getElementById('appName');
const descriptionInput = document.getElementById('description');
const teamEmailInput = document.getElementById('teamEmail');
const portInput = document.getElementById('port');
const replicasInput = document.getElementById('replicas');
const memoryRequestSelect = document.getElementById('memoryRequest');
const memoryLimitSelect = document.getElementById('memoryLimit');
const cpuRequestSelect = document.getElementById('cpuRequest');
const cpuLimitSelect = document.getElementById('cpuLimit');
const deployButton = document.getElementById('deployButton');
const backToStep1Button = document.getElementById('backToStep1Button');
const backToStep2Button = document.getElementById('backToStep2Button');
const continueToStep3Button = document.getElementById('continueToStep3Button');
const deploymentSpinner = document.getElementById('deploymentSpinner');
const deploymentSuccess = document.getElementById('deploymentSuccess');
const deploymentError = document.getElementById('deploymentError');
const errorMessage = document.getElementById('errorMessage');
const projectURL = document.getElementById('projectURL');
const devURL = document.getElementById('devURL');
const prodURL = document.getElementById('prodURL');
const startOverButton = document.getElementById('startOverButton');
const retryButton = document.getElementById('retryButton');

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    // Fetch CSRF token for API requests
    fetchCSRFToken();
    
    // Fetch application templates
    fetchTemplates();
    
    // Set up button event listeners
    backToStep1Button.addEventListener('click', () => navigateToStep(1));
    backToStep2Button.addEventListener('click', () => navigateToStep(2));
    continueToStep3Button.addEventListener('click', validateAndContinueToStep3);
    deployButton.addEventListener('click', deployApplication);
    startOverButton.addEventListener('click', resetAndStartOver);
    retryButton.addEventListener('click', retryDeployment);
    
    // Status modal functionality
    const checkStatusBtn = document.getElementById('checkStatusBtn');
    checkStatusBtn.addEventListener('click', checkApplicationStatus);
    
    // Add validation to the app name input
    appNameInput.addEventListener('input', function() {
        const value = this.value.toLowerCase();
        const sanitized = value.replace(/[^a-z0-9-]/g, '-');
        this.value = sanitized;
    });
});

/**
 * Fetch CSRF token for secure API requests
 */
function fetchCSRFToken() {
    fetch('/api/csrf-token')
        .then(response => response.json())
        .then(data => {
            csrfToken = data.csrf_token;
            console.log('CSRF token obtained');
        })
        .catch(error => {
            console.error('Failed to get CSRF token:', error);
        });
}

/**
 * Fetch application templates from the API
 */
function fetchTemplates() {
    fetch('/api/templates')
        .then(response => response.json())
        .then(templates => {
            displayTemplates(templates);
        })
        .catch(error => {
            console.error('Error fetching templates:', error);
            templatesContainer.innerHTML = '<div class="alert alert-danger">Failed to load templates. Please refresh the page.</div>';
        });
}

/**
 * Display templates in the UI
 */
function displayTemplates(templates) {
    templatesContainer.innerHTML = '';
    
    templates.forEach(template => {
        const templateCard = document.createElement('div');
        templateCard.className = 'col-md-3 mb-4';
        templateCard.innerHTML = `
            <div class="template-card card h-100 text-center" data-template-id="${template.id}">
                <div class="card-body">
                    <i class="${template.icon} template-icon" style="color: ${template.color};"></i>
                    <h5 class="card-title">${template.name}</h5>
                    <p class="card-text small">${template.description}</p>
                </div>
                <div class="card-footer bg-white">
                    <small class="text-muted">Default Port: ${template.default_port}</small>
                </div>
            </div>
        `;
        
        // Store the frameworks for this template
        templateCard.querySelector('.template-card').addEventListener('click', () => {
            // Remove selected class from all templates
            document.querySelectorAll('.template-card').forEach(card => {
                card.classList.remove('selected');
            });
            
            // Add selected class to this template
            templateCard.querySelector('.template-card').classList.add('selected');
            
            // Store the selected template
            selectedTemplate = template;
            selectedFrameworks = template.frameworks;
            
            // Update the port to the template's default port
            portInput.value = template.default_port;
            
            // Update the framework dropdown
            updateFrameworkOptions();
            
            // Navigate to step 2
            navigateToStep(2);
        });
        
        templatesContainer.appendChild(templateCard);
    });
}

/**
 * Update the framework dropdown based on the selected template
 */
function updateFrameworkOptions() {
    frameworkSelect.innerHTML = '';
    
    // Add an option for the template itself
    const defaultOption = document.createElement('option');
    defaultOption.value = selectedTemplate.id;
    defaultOption.textContent = selectedTemplate.name;
    frameworkSelect.appendChild(defaultOption);
    
    // Add an option for each framework
    selectedFrameworks.forEach(framework => {
        const option = document.createElement('option');
        option.value = framework.toLowerCase().replace(/\s+/g, '-');
        option.textContent = framework;
        frameworkSelect.appendChild(option);
    });
}

/**
 * Navigate to a specific step
 */
function navigateToStep(step) {
    currentStep = step;
    
    // Hide all step cards
    step1Card.style.display = 'none';
    step2Card.style.display = 'none';
    step3Card.style.display = 'none';
    step4Card.style.display = 'none';
    
    // Show the current step card
    if (step === 1) {
        step1Card.style.display = 'block';
    } else if (step === 2) {
        step2Card.style.display = 'block';
    } else if (step === 3) {
        step3Card.style.display = 'block';
    } else if (step === 4) {
        step4Card.style.display = 'block';
    }
    
    // Scroll to the top of the visible card
    window.scrollTo({
        top: 0,
        behavior: 'smooth'
    });
}

/**
 * Validate step 2 and continue to step 3
 */
function validateAndContinueToStep3() {
    // Simple validation
    const appName = appNameInput.value.trim();
    const description = descriptionInput.value.trim();
    const teamEmail = teamEmailInput.value.trim();
    
    if (!appName) {
        alert('Please enter an application name');
        appNameInput.focus();
        return;
    }
    
    if (!description) {
        alert('Please enter a description');
        descriptionInput.focus();
        return;
    }
    
    if (!teamEmail) {
        alert('Please enter a team email');
        teamEmailInput.focus();
        return;
    }
    
    // Check email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(teamEmail)) {
        alert('Please enter a valid email address');
        teamEmailInput.focus();
        return;
    }
    
    // All validations passed, navigate to step 3
    navigateToStep(3);
}

/**
 * Deploy the application
 */
function deployApplication() {
    // Show the spinner
    navigateToStep(4);
    deploymentSpinner.style.display = 'block';
    deploymentSuccess.style.display = 'none';
    deploymentError.style.display = 'none';
    
    // Collect all the form data
    const appData = {
        app_name: appNameInput.value.trim(),
        description: descriptionInput.value.trim(),
        team_email: teamEmailInput.value.trim(),
        framework: frameworkSelect.value,
        port: parseInt(portInput.value, 10),
        replicas: parseInt(replicasInput.value, 10),
        memory_request: memoryRequestSelect.value,
        memory_limit: memoryLimitSelect.value,
        cpu_request: cpuRequestSelect.value,
        cpu_limit: cpuLimitSelect.value
    };
    
    // Call the API to onboard the application
    fetch('/api/onboard', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken // Include CSRF token in the request
        },
        body: JSON.stringify(appData)
    })
    .then(response => response.json())
    .then(data => {
        deploymentSpinner.style.display = 'none';
        
        if (data.status === 'success') {
            // Store deployment data
            deploymentData = data;
            
            // Update success section
            projectURL.href = data.project_url;
            devURL.href = data.dev_url;
            prodURL.href = data.prod_url;
            
            // Show success section
            deploymentSuccess.style.display = 'block';
        } else {
            // Show error section
            errorMessage.textContent = data.message || 'An error occurred during deployment';
            deploymentError.style.display = 'block';
        }
    })
    .catch(error => {
        console.error('Error deploying application:', error);
        deploymentSpinner.style.display = 'none';
        errorMessage.textContent = 'Network error occurred. Please try again.';
        deploymentError.style.display = 'block';
    });
}

/**
 * Reset the form and start over
 */
function resetAndStartOver() {
    // Reset form fields
    appNameInput.value = '';
    descriptionInput.value = '';
    teamEmailInput.value = '';
    portInput.value = '8080';
    replicasInput.value = '3';
    memoryRequestSelect.value = '256Mi';
    memoryLimitSelect.value = '512Mi';
    cpuRequestSelect.value = '100m';
    cpuLimitSelect.value = '500m';
    
    // Reset selected template
    selectedTemplate = null;
    selectedFrameworks = [];
    document.querySelectorAll('.template-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    // Go back to step 1
    navigateToStep(1);
}

/**
 * Retry the deployment
 */
function retryDeployment() {
    deployApplication();
}

/**
 * Check application status
 */
function checkApplicationStatus() {
    const appName = document.getElementById('appNameStatus').value.trim();
    const statusResult = document.getElementById('statusResult');
    const statusError = document.getElementById('statusError');
    const statusAppName = document.getElementById('statusAppName');
    const statusTableBody = document.getElementById('statusTableBody');
    
    if (!appName) {
        statusError.textContent = 'Please enter an application name';
        statusError.style.display = 'block';
        statusResult.style.display = 'none';
        return;
    }
    
    // Hide previous results
    statusError.style.display = 'none';
    statusResult.style.display = 'none';
    
    // Call the API to check status
    fetch(`/api/status/${appName}`)
        .then(response => response.json())
        .then(data => {
            if (data.status === 'success') {
                statusAppName.textContent = data.app_name;
                
                // Clear previous results
                statusTableBody.innerHTML = '';
                
                // Add environments
                for (const [envName, envData] of Object.entries(data.environments)) {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${envName}</td>
                        <td><span class="badge ${envData.status === 'available' ? 'bg-success' : 'bg-warning'}">${envData.status}</span></td>
                        <td>${new Date(envData.last_deployment).toLocaleString()}</td>
                        <td>
                            <a href="${envData.url}" target="_blank" class="btn btn-sm btn-outline-primary">
                                <i class="fas fa-external-link-alt"></i>
                            </a>
                        </td>
                    `;
                    statusTableBody.appendChild(row);
                }
                
                // Show results
                statusResult.style.display = 'block';
            } else {
                statusError.textContent = data.message;
                statusError.style.display = 'block';
            }
        })
        .catch(error => {
            console.error('Error checking application status:', error);
            statusError.textContent = 'An error occurred while checking the application status';
            statusError.style.display = 'block';
        });
}
